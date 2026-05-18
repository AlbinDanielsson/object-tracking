clear; clc; close all;

myDaq = daq("ni");
myDaq.Rate = 100000; % match second script

% Digital trigger output
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");

% Echo input
addinput(myDaq, "myDAQ1", "ai0", "Voltage");

repetitions = 3;
pauseBetweenTriggers = 0.4;   % 400 ms
pulseLength = 0.001;          % 1 ms
echoThresh = 2.0;

% Storage
allDistances = [];

% Plot setup
figure;
hPlot = plot(nan, nan, 'LineWidth', 1.5);
xlabel('Sample');
ylabel('Voltage (V)');
title('Live Echo Signal');
grid on;
ylim([-0.5 5.5]);

write(myDaq, false);

while ishandle(hPlot)

    % Collect echo data window
    echo = read(myDaq, seconds(0.05)); % 50 ms window

    echoSignal = echo{:,1};

    % Trigger pulses
    for k = 1:repetitions
        write(myDaq, true);
        pause(pulseLength);
        write(myDaq, false);
        pause(0.01); % small spacing between pulses
    end

    % Process echoes
    widths = getEchoWidths(echoSignal, echoThresh, repetitions);
    cm = widths / 5.8;

    % Store results
    allDistances = [allDistances; cm'];

    fprintf('Sensor 1: %.1f %.1f %.1f cm\n', ...
        cm(1), cm(2), cm(3));

    % Update plot
    set(hPlot, 'XData', 1:length(echoSignal), ...
               'YData', echoSignal);

    drawnow;

    pause(pauseBetweenTriggers);
end

write(myDaq, false);


function echoWidths = getEchoWidths(echo, echoThresh, repetitions)

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