clear;
clc;

%testing Params
maxSample = 20;
samplesPerState = 2;
pauseLength = 6; %seconds

pause(5);

%Real values 
realY = zeros(1, 10) + 110; 
realAngle = [0, 10, 20, 30, 0, ...
        -10, 10, -20, -30, 0];
realX = zeros(1, 10);

%Error vectors
seenY = zeros(1, 20);
seenX = zeros(1, 20);
seenAngle = zeros(1, 20);

%initial parameters
l = 15.4; %cm
objectWidth = 100; %cm
objectCenter = [0, 110];%cm
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

%% 
% setting up big display

figure;
set(gcf, 'Color', 'white');
axis off;

hText = text(0.5, 0.5, "", ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 120, ...
    'FontWeight', 'bold', ...
    'Color', 'black');

%% 
%Setting up filter
% True EKF state: [x; y; theta; vx; vy; omega]
Xhat = [0; objectCenter(2); objectAngle; 0; 0; 0];

P = diag([5^2, 80^2, deg2rad(30)^2, 5^2, 30^2, deg2rad(20)^2]);
Q = diag([0.1, 2, deg2rad(1)^2, 0.1, 10, deg2rad(5)^2]);

% Measurement: [r1; r2]
R = diag([6^2, 6^2]);

maxRange = 350;
sensorEA = deg2rad(sensorDeg);

filterInitialized = false;

%% 
%Main loop

for samples = 1:1:maxSample
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
   validMeasurement = isValid(r1, r2);
    % State transition
    F = [1 0 0 dt 0  0;
        0 1 0 0  dt 0;
        0 0 1 0  0  dt;
        0 0 0 1  0  0;
        0 0 0 0  1  0;
        0 0 0 0  0  1];

    if validMeasurement && ~filterInitialized
        angle0 = flatObjectAngle(r1, r2, l);
        distance0 = flatObjectDistance(r1, r2);
        Xhat = [0; distance0; angle0; 0; 0; 0];
        filterInitialized = true;
    end

    % ---------- Prediction ----------
    Xhat = F * Xhat;
    Xhat(3) = wrapToPiLocal(Xhat(3));
    P = F * P * F' + Q;

    if validMeasurement

        z = [r1; r2];

        hFun = @(X) [
            expectedSensorReading(X(1:3),  l/2, objectWidth, maxRange, sensorEA);
            expectedSensorReading(X(1:3), -l/2, objectWidth, maxRange, sensorEA)
        ];

        % ---------- Correction ----------
        zPred = hFun(Xhat);
        H = numericalJacobian(hFun, Xhat);

        innovation = z - zPred;

        S = H * P * H' + R;
        K = P * H' / S;

        gate = innovation' / S * innovation;

        if gate < 25
    Xhat = Xhat + K * innovation;
    Xhat(3) = wrapToPiLocal(Xhat(3));
    P = (eye(6) - K * H) * P;
        end
    end

    objectCenter = Xhat(1:2)';
    objectAngle = Xhat(3);

    seenX(samples) = objectCenter(1);
    seenY(samples) = objectCenter(2);
    seenAngle(samples) = objectAngle;
    
    %% 
    %Plot loop
    
    %% 
% Big display loop

stateIndex = ceil(samples / samplesPerState);

% Show current realY in large text
set(hText, ...
    'String', sprintf('a = %.0f deg', realAngle(stateIndex)), ...
    'Color', 'black');

drawnow;

fprintf('position: %.1f, %.1f\n', objectCenter);
fprintf('KF\n\n');

% After every second sample: red pause so object can be moved
if mod(samples, samplesPerState) == 0 && samples < maxSample

    nextStateIndex = stateIndex + 1;

    set(hText, ...
        'String', sprintf('MOVE TO\na = %.0f deg', realAngle(nextStateIndex)), ...
        'Color', 'red');

    drawnow;
    pause(pauseLength);
end
end

seenY
seenX
seenAngle

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

function a = wrapToPiLocal(a)
    a = mod(a + pi, 2*pi) - pi;
end

%%helpers
function H = numericalJacobian(hFun, X)
    z0 = hFun(X);
    n = numel(X);
    m = numel(z0);
    H = zeros(m, n);

    for i = 1:n
        dX = zeros(n,1);

        if i == 3 || i == 6
            step = 1e-4;
        else
            step = 1e-3;
        end

        dX(i) = step;

        zp = hFun(X + dX);
        zm = hFun(X - dX);

        H(:,i) = (zp - zm) / (2 * step);
    end
end