clear;
clc;

%initial parameters
l = 15.4; %cm
objectWidth = 100; %cm
objectCenter = [0, 100];%cm
objectAngle = 0;%rads

sensorEA = pi/20;
sensorDeg = 8.5;

dt = 0.4; %TODO, calculate!

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
%Setting up filter
% State: [x; y; theta; vx; vy; omega]
Xhat = [0; 400; 0; 0; 0; 0];

P = diag([5^2, 80^2, deg2rad(30)^2, 5^2, 30^2, deg2rad(20)^2]);
Q = diag([0.1, 2, deg2rad(1)^2, 0.1, 10, deg2rad(5)^2]);

% Measurement: [x; y; theta]
R = diag([2^2, 8^2, deg2rad(5)^2]);

filterInitialized = false;

xLog = [];
yLog = [];
thetaLog = [];
tLog = [];
filterTic = tic;
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

    %% 
    %filter
    % Reject invalid max-range readings
validMeasurement = r1 < 350 && r2 < 350 && distance > 2 && distance < 350;

if validMeasurement

    z = [0; distance; angle];

    if ~filterInitialized
        Xhat = [0; distance; angle; 0; 0; 0];
        filterInitialized = true;
    end

    F = [1 0 0 dt 0  0;
         0 1 0 0  dt 0;
         0 0 1 0  0  dt;
         0 0 0 1  0  0;
         0 0 0 0  1  0;
         0 0 0 0  0  1];

    Xhat = F * Xhat;
    Xhat(3) = wrapToPiLocal(Xhat(3));
    P = F * P * F' + Q;

    H = [1 0 0 0 0 0;
         0 1 0 0 0 0;
         0 0 1 0 0 0];

    innovation = z - H * Xhat;
    innovation(3) = wrapToPiLocal(innovation(3));

    S = H * P * H' + R;
    K = P * H' / S;

    gate = innovation' / S * innovation;

    if gate < 25
        Xhat = Xhat + K * innovation;
        P = (eye(6) - K * H) * P;
    end

    Xhat(3) = wrapToPiLocal(Xhat(3));

else
    % Prediction only if reading is bad
    F = [1 0 0 dt 0  0;
         0 1 0 0  dt 0;
         0 0 1 0  0  dt;
         0 0 0 1  0  0;
         0 0 0 0  1  0;
         0 0 0 0  0  1];

    Xhat = F * Xhat;
    Xhat(3) = wrapToPiLocal(Xhat(3));
    P = F * P * F' + Q;
end

objectCenter = Xhat(1:2)';
objectAngle = Xhat(3);

xLog(end+1) = Xhat(1);
yLog(end+1) = Xhat(2);
thetaLog(end+1) = Xhat(3);
tLog(end+1) = toc(filterTic);
    
    
    %% 
    %Plot loop
    
    %Plot object
    xObj = [objectCenter(1) - cos(objectAngle)*objectWidth/2, ...
            objectCenter(1) + cos(objectAngle)*objectWidth/2];
    yObj = [objectCenter(2) - sin(objectAngle)*objectWidth/2, ...
            objectCenter(2) + sin(objectAngle)*objectWidth/2];
    set(hObj, 'XData', xObj, 'YData', yObj);
    drawnow

    fprintf('position: %.1f, %.1f\n', objectCenter);
    fprintf('EKF\n\n')
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

%%helpers
function H = numericalJacobian(hFun, X)
    z0 = hFun(X);
    n = numel(X);
    m = numel(z0);
    H = zeros(m, n);

    epsVal = 1e-3;

    for i = 1:n
        dX = zeros(n,1);

        if i == 3 || i == 6
            step = 1e-4;
        else
            step = epsVal;
        end

        dX(i) = step;

        zp = hFun(X + dX);
        zm = hFun(X - dX);

        H(:,i) = (zp - zm) / (2 * step);
    end
end

function a = wrapToPiLocal(a)
    a = mod(a + pi, 2*pi) - pi;
end