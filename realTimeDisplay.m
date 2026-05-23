clear;
clc;

%initial parameters
l = 15.4; %cm
objectWidth = 100; %cm
objectCenter = [0, 400];%cm
objectAngle = 0;%rads

pause(10);

sensorEA = pi/20;
sensorDeg = 8.5;

dt = 0.4; %TODO, calculate!

%Velocity calculation
vel = [0, 0];
omega = 0;
lastPos = objectCenter;
lastAngle = objectAngle;

%%
% Setting up signals
myDaq = daq("ni");
myDaq.Rate = 100000;   % 100 kHz → 10 us per sample


addoutput(myDaq, "myDAQ1", "ao0", "Voltage"); % Sensor 1 TRIG
addinput(myDaq,  "myDAQ1", "ai0", "Voltage"); % Sensor 1 ECHO

addoutput(myDaq, "myDAQ1", "ao1", "Voltage"); % Sensor 2 TRIG
addinput(myDaq,  "myDAQ1", "ai1", "Voltage"); % Sensor 2 ECHO

cycleLength = 40 * 100;   %40 ms between triggers
repetitions = 3;
triggerVoltage = 3;

% One trigger pulse per cycle
pulse1 = zeros(cycleLength,1);
pulse2 = zeros(cycleLength,1);

pulse1(end) = triggerVoltage;  % trigger sensor 1
pulse2(end) = 0;

sensor1Cycle = [pulse1 pulse2];

pulse1 = zeros(cycleLength,1);
pulse2 = zeros(cycleLength,1);

pulse1(end) = 0;
pulse2(end) = triggerVoltage;  % trigger sensor 2

sensor2Cycle = [pulse1 pulse2];

% Alternate sensor 1, sensor 2
pulse = [];
for k = 1:repetitions
    pulse = [pulse; sensor1Cycle; sensor2Cycle];
end

% Extra quiet time at end
pulse = [pulse; zeros(cycleLength,2)];

[data, time] = readwrite(myDaq, pulse);

t = seconds(data.Time);

echo1 = data{:,1};   % ai0
echo2 = data{:,2};   % ai1

echoThresh = 2;
%% 
% setting up plot

figure;
hold on;
axis equal;
xlim([-100 100]);
ylim([0 400]);

%Checkerboard
squareSize = 50;
xEdges = -200:squareSize:200;
yEdges = 0:squareSize:400;
for i = 1:length(xEdges)-1
    for j = 1:length(yEdges)-1
        if mod(i+j,2) == 0
            shade = 0.75;
        else
            shade = 0.9;
        end
        rectangle( ...
            'Position', [xEdges(i), yEdges(j), squareSize, squareSize], ...
            'FaceColor', [shade shade shade], ...
            'EdgeColor', 'none');
    end
end

%plot sensors
plot(l/2, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
plot(-l/2, 0, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
xlabel('x');
ylabel('y');
box on;
xSensor = [l/2, -l/2];
ySensor = [0, 0];

for k = 1:length(xSensor)

    % Left and right cone boundary slopes
    dx = 400 * tand(sensorDeg/2);

    xLeft  = xSensor(k) - dx;
    xRight = xSensor(k) + dx;

    % Shade sensor field of view
    if k == 1
        coneColor = [1 0 0];   % red
    else
        coneColor = [0 1 0];   % green
    end

    patch( ...
        [xSensor(k), xLeft, xRight], ...
        [0,          400,     400], ...
        coneColor, ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', 'none');

    % Draw cone boundary lines up to y = 4
    plot([xSensor(k), xLeft],  [0, 400], 'k-', 'LineWidth', 1);
    plot([xSensor(k), xRight], [0, 400], 'k-', 'LineWidth', 1);
end
% Initial object endpoints
xObj = [objectCenter(1) - cos(objectAngle)*objectWidth/2, ...
        objectCenter(1) + cos(objectAngle)*objectWidth/2];

yObj = [objectCenter(2) - sin(objectAngle)*objectWidth/2, ...
        objectCenter(2) + sin(objectAngle)*objectWidth/2];

% Create object once
hObj = plot(xObj, yObj, 'color', 'blue', 'LineWidth', 3);

%% 
%Setting up EKF
X = [objectCenter(1); objectCenter(2); objectAngle];
x_pred = [0, 0, 0];

%Parameters, TODO update/replace
sigma_x = 10; %cm per timestep
sigma_y = 3;
sigma_theta = deg2rad(5); % rad

sigma_r = 2.5; %cm sensor noise
P = diag([5^2, 5^2, deg2rad(20)^2]);

%derived
Q = diag([sigma_x^2, sigma_y^2, sigma_theta^2]);
W = diag([sigma_r^2, sigma_r^2]);

%Initialize others
P_pred = zeros(3, 3);
H = zeros(2, 3);
Z = zeros(2, 1);
z_pred = zeros(2, 1);

%% 
%Main loop

while true
    data = readwrite(myDaq, pulse);

    echo1 = data{:,1};
    echo2 = data{:,2};

    widths1 = getEchoWidths(echo1, echoThresh);
    widths2 = getEchoWidths(echo2, echoThresh);

    cm1 = widths1 / 5.8;
    cm2 = widths2 / 5.8;

    %Remove 400 cm, usually that is a error
    cm1 = cm1(cm1 <= 450);
    cm2 = cm2(cm2 <= 450);
    if isempty(cm1)
        cm1 = [400];
    end
    if isempty(cm2)
        cm2 = [400];
    end

    r1 = median(cm1);
    r2 = median(cm2);
    fprintf('r1 = %.1f, r2 = %.1f \n', r1,r2);

    angle = flatObjectAngle(r1, r2, l);
    distance = flatObjectDistance(r1, r2);
    fprintf('angle %.1f, distance %.1f \n', angle * 180/pi, distance);

    validSensors = true;
    if abs(r1 - r2) > l %(impossible)
        validSensors = false;
    end
    if angle > pi/10 %should not be possible
        validSensors = false;
    end
    
    if validSensors == false
        fprintf("\nSKIP!\n\n");
        continue
    end

    %% 
    %EKF loop
    X_pred = [X(1) + vel(1)*dt;
          X(2) + vel(2)*dt;
          wrapToPi(X(3) + omega*dt)];

    %Calculate H
    H = calculateH(X(3), l);

    %F_x, jacobian
    F_x = eye(3);

    %P_pred
    P_pred = F_x * P * F_x' + Q;

    %Innovation
    z_pred(1) = expectedSensorReading(X, -l/2, objectWidth, 400, sensorEA);
    z_pred(2) = expectedSensorReading(X, l/2, objectWidth, 400, sensorEA);
    Z = [r1; r2]; %real reading
    v = Z - z_pred;

    %Kalman update and gain equations
    S = H*P_pred*H' + W;
    K = P_pred * H' / S;

    %correction equations
    X = X_pred + K * v;
    X(3) = wrapToPi(X(3));
    P = (eye(3) - K*H) * P_pred;

    %objectCenter = X(1:2)';
    %objectAngle = X(3);

    %Hand written Estimate
    objectCenter = [0, distance];
    objectAngle = angle;
    
    %% 
    %Plot loop
    
    %Plot object
    xObj = [objectCenter(1) - cos(objectAngle)*objectWidth/2, ...
            objectCenter(1) + cos(objectAngle)*objectWidth/2];
    yObj = [objectCenter(2) - sin(objectAngle)*objectWidth/2, ...
            objectCenter(2) + sin(objectAngle)*objectWidth/2];
    set(hObj, 'XData', xObj, 'YData', yObj);
    drawnow

    %Update velocities
    omega = (objectAngle - lastAngle)/dt;
    lastAngle = objectAngle;
    vel = (objectCenter - lastPos)/dt;
    lastPos = objectCenter;

    %fprintf('errors: %.1f, %.1f\n', error1, error2);
    fprintf('velocity: %.1f, %.1f\n', vel);

    fprintf('position: %.1f, %.1f\n\n', objectCenter);
end

%%
%functions
function echoWidths = getEchoWidths(echo, echoThresh)

    repetitions = 3;
    echoWidths = zeros(repetitions,1);

    bEcho = false;
    eStart = 0;
    echoIndex = 1;

    for i = 1:numel(echo)

        if ~bEcho
            if echo(i) > echoThresh
                bEcho = true;
                eStart = i;
            end
        else
            if echo(i) < echoThresh
                bEcho = false;
                eEnd = i;

                if echoIndex <= repetitions
                    echoWidths(echoIndex) = eEnd - eStart;
                    echoIndex = echoIndex + 1;
                end
            end
        end
    end
end
