clear; clc; close all;

myDaq = daq("ni");

% Digital trigger output
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");

% Analog echo input
addinput(myDaq, "myDAQ1", "ai0", "Voltage");

repetitions = 3;
pauseBetweenPulses = 0.5;   % 50 ms
pulseLength = 0.001;         % 1 ms, approximate
echoThresh = 2.0;

echoWidths = zeros(repetitions, 1);

figure;

subplot(2,1,1);
hTrigger = stairs(0, 0, 'LineWidth', 1.5);
xlabel('Sample');
ylabel('Digital State');
title('Trigger Signal');
ylim([-0.5 1.5]);
grid on;

subplot(2,1,2);
hEcho = plot(0, 0, 'LineWidth', 1.5);
xlabel('Sample');
ylabel('Voltage (V)');
title('Analog Echo Signal');
ylim([-0.5 5.5]);
grid on;

while ishandle(hEcho)

    triggerLog = [];
    echoLog = [];

    for k = 1:repetitions

        write(myDaq, true);
        triggerLog(end+1,1) = 1;
        d = read(myDaq);
        echoLog(end+1,1) = d{1,1};

        pause(pulseLength);

        write(myDaq, false);
        triggerLog(end+1,1) = 0;
        d = read(myDaq);
        echoLog(end+1,1) = d{1,1};

        tic;
        while toc < pauseBetweenPulses
            triggerLog(end+1,1) = 0;
            d = read(myDaq);
            echoLog(end+1,1) = d{1,1};
        end

    end

    echoWidths(:) = 0;
    echoIndex = 1;
    bEcho = false;

    for i = 1:numel(echoLog)

        if ~bEcho && echoLog(i) > echoThresh
            bEcho = true;
            eStart = i;

        elseif bEcho && echoLog(i) < echoThresh
            bEcho = false;
            eEnd = i;

            if echoIndex <= repetitions
                echoWidths(echoIndex) = eEnd - eStart;
                echoIndex = echoIndex + 1;
            end
        end

    end

    fprintf('Echo widths in software samples: %d, %d, %d\n', echoWidths);

    set(hTrigger, 'XData', 1:numel(triggerLog), 'YData', triggerLog);
    set(hEcho, 'XData', 1:numel(echoLog), 'YData', echoLog);

    drawnow;

end

write(myDaq, false);