clear;
clc;

myDaq = daq("ni");
myDaq.Rate = 100000;   % 100 kHz → 10 us per sample
l = 15.4; %cm

addoutput(myDaq, "myDAQ1", "ao0", "Voltage"); % Sensor 1 TRIG
addinput(myDaq,  "myDAQ1", "ai0", "Voltage"); % Sensor 1 ECHO

addoutput(myDaq, "myDAQ1", "ao1", "Voltage"); % Sensor 2 TRIG
addinput(myDaq,  "myDAQ1", "ai1", "Voltage"); % Sensor 2 ECHO

cycleLength = 400 * 100;   %400 ms between triggers
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

figure;

subplot(3,1,1);
plot(t*1000, pulse(:,1), t*1000, pulse(:,2), 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Voltage (V)');
title('Trigger Signals');
legend('Sensor 1 TRIG', 'Sensor 2 TRIG');
ylim([-0.5 5.5]);
grid on;

subplot(3,1,2);
hEcho1 = plot(t*1000, echo1, 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Voltage (V)');
title('Sensor 1 Echo');
ylim([-0.5 5.5]);
grid on;

subplot(3,1,3);
hEcho2 = plot(t*1000, echo2, 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Voltage (V)');
title('Sensor 2 Echo');
ylim([-0.5 5.5]);
grid on;

echoThresh = 2;

while ishandle(hEcho1)
    data = readwrite(myDaq, pulse);

    echo1 = data{:,1};
    echo2 = data{:,2};

    widths1 = getEchoWidths(echo1, echoThresh);
    widths2 = getEchoWidths(echo2, echoThresh);

    cm1 = widths1 / 5.8;
    cm2 = widths2 / 5.8;
    pos = triangle(median(cm1), median(cm2), l);
    %fprintf('(%.1f, %.1f), r1 = %.1f, r2 = %.1f \n', pos(1), pos(2), median(cm1), median(cm2));
    fprintf('r1 = %.1f, r2 = %.1f \n', median(cm1), median(cm2));

    angle = flatObjectAngle(median(cm1), median(cm2), l);
    distance = flatObjectDistance(median(cm1), median(cm2));
    fprintf('angle %.1f, distance %.1f \n \n', angle * 180/pi, distance);

    set(hEcho1, 'YData', echo1);
    set(hEcho2, 'YData', echo2);

    drawnow;
end


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