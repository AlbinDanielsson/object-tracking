clear;
clc;

%initial parameters
l = 15.4; %cm
objectWidth = 20; %cm
objectCenter = [0, 30];%cm
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
% UKF state: [x; y; theta; vx; vy; omega]
n = 6;
Xhat = [0; objectCenter(2); objectAngle; 0; 0; 0];

P = diag([5^2, 50^2, deg2rad(20)^2, 5^2, 30^2, deg2rad(20)^2]);
Q = diag([0.2^2, 2^2, deg2rad(1)^2, 1^2, 8^2, deg2rad(4)^2]);

% Measurement: [x; y; theta]
R = diag([3^2, 6^2, deg2rad(4)^2]);

alpha = 0.4;
beta = 2;
kappa = 0;

lambda = alpha^2 * (n + kappa) - n;

Wm = [lambda/(n+lambda), repmat(1/(2*(n+lambda)), 1, 2*n)];
Wc = Wm;
Wc(1) = Wc(1) + (1 - alpha^2 + beta);

filterInitialized = false;
maxRange = 350;

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
    validMeasurement = r1 < maxRange && r2 < maxRange && distance > 2 && distance < maxRange;

if validMeasurement

    z = [0; distance; angle];

    if ~filterInitialized
        Xhat = [0; distance; angle; 0; 0; 0];
        filterInitialized = true;
    end

    % ---------- UKF prediction ----------
    Xsig = sigmaPoints(Xhat, P, lambda);

    XpredSig = zeros(size(Xsig));

    for i = 1:size(Xsig,2)
        XpredSig(:,i) = processModelUKF(Xsig(:,i), dt);
    end

    Xpred = weightedMeanState(XpredSig, Wm);
    Ppred = Q;

    for i = 1:size(XpredSig,2)
        dx = stateDiff(XpredSig(:,i), Xpred);
        Ppred = Ppred + Wc(i) * (dx * dx');
    end

    % ---------- UKF measurement prediction ----------
    m = 3;
    Zsig = zeros(m, size(XpredSig,2));

    for i = 1:size(XpredSig,2)
        Zsig(:,i) = measurementModelUKF(XpredSig(:,i));
    end

    zPred = weightedMeanMeas(Zsig, Wm);

    S = R;
    Pxz = zeros(n,m);

    for i = 1:size(XpredSig,2)
        dz = measDiff(Zsig(:,i), zPred);
        dx = stateDiff(XpredSig(:,i), Xpred);

        S = S + Wc(i) * (dz * dz');
        Pxz = Pxz + Wc(i) * (dx * dz');
    end

    innovation = measDiff(z, zPred);

    % Outlier gate
    gate = innovation' / S * innovation;

    if gate < 25
        K = Pxz / S;
        Xhat = Xpred + K * innovation;
        P = Ppred - K * S * K';
    else
        Xhat = Xpred;
        P = Ppred;
    end

else
    % Prediction only
    Xsig = sigmaPoints(Xhat, P, lambda);

    XpredSig = zeros(size(Xsig));
    for i = 1:size(Xsig,2)
        XpredSig(:,i) = processModelUKF(Xsig(:,i), dt);
    end

    Xhat = weightedMeanState(XpredSig, Wm);
    P = Q;

    for i = 1:size(XpredSig,2)
        dx = stateDiff(XpredSig(:,i), Xhat);
        P = P + Wc(i) * (dx * dx');
    end
end

% Physical limits
Xhat(1) = min(max(Xhat(1), -100), 100);
Xhat(2) = min(max(Xhat(2), 2), 400);
Xhat(3) = wrapToPiLocal(Xhat(3));
Xhat(3) = min(max(Xhat(3), deg2rad(-45)), deg2rad(45));

objectCenter = Xhat(1:2)';
objectAngle = Xhat(3);

xLog(end+1) = objectCenter(1);
yLog(end+1) = objectCenter(2);
thetaLog(end+1) = objectAngle;
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

function Xsig = sigmaPoints(x, P, lambda)
    n = numel(x);
    P = (P + P') / 2;

    jitter = 1e-6 * eye(n);
    A = chol((n + lambda) * (P + jitter), 'lower');

    Xsig = zeros(n, 2*n + 1);
    Xsig(:,1) = x;

    for i = 1:n
        Xsig(:,i+1)   = x + A(:,i);
        Xsig(:,i+1+n) = x - A(:,i);
    end

    Xsig(3,:) = wrapToPiLocal(Xsig(3,:));
end

function xNext = processModelUKF(x, dt)
    xNext = x;

    xNext(1) = x(1) + x(4)*dt;
    xNext(2) = x(2) + x(5)*dt;
    xNext(3) = x(3) + x(6)*dt;

    xNext(3) = wrapToPiLocal(xNext(3));
end

function z = measurementModelUKF(x)
    % Measurement: [x; y; theta]
    z = [x(1); x(2); x(3)];
end

function xMean = weightedMeanState(Xsig, Wm)
    xMean = Xsig * Wm';

    s = sum(Wm .* sin(Xsig(3,:)));
    c = sum(Wm .* cos(Xsig(3,:)));
    xMean(3) = atan2(s, c);
end

function zMean = weightedMeanMeas(Zsig, Wm)
    zMean = Zsig * Wm';

    s = sum(Wm .* sin(Zsig(3,:)));
    c = sum(Wm .* cos(Zsig(3,:)));
    zMean(3) = atan2(s, c);
end

function dx = stateDiff(a, b)
    dx = a - b;
    dx(3) = wrapToPiLocal(dx(3));
end

function dz = measDiff(a, b)
    dz = a - b;
    dz(3) = wrapToPiLocal(dz(3));
end

function a = wrapToPiLocal(a)
    a = mod(a + pi, 2*pi) - pi;
end
