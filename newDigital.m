clear; clc; close all;

myDaq = daq("ni");

% Digital trigger outputs
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital"); % Sensor 1 TRIG
addoutput(myDaq, "myDAQ1", "port0/line1", "Digital"); % Sensor 2 TRIG

% Echo inputs
addinput(myDaq, "myDAQ1", "ai0", "Voltage"); % Sensor 1 ECHO
addinput(myDaq, "myDAQ1", "ai1", "Voltage"); % Sensor 2 ECHO

repetitions = 3;
pauseBetweenTriggers = 0.4;   % 400 ms
pulseLength = 0.001;          % 1 ms
echoThresh = 2.0;

figure;

subplot(3,1,1);
hTrig1 = stairs(0,0,'LineWidth',1.5); hold on;
hTrig2 = stairs(0,0,'LineWidth',1.5);
xlabel('Sample');
ylabel('Digital State');
title('Trigger Signals');
legend('Sensor 1 TRIG','Sensor 2 TRIG');
ylim([-0.5 1.5]);
grid on;

subplot(3,1,2);
hEcho1 = plot(0,0,'LineWidth',1.5);
xlabel('Sample');
ylabel('Voltage (V)');
title('Sensor 1 Echo');
ylim([-0.5 5.5]);
grid on;

subplot(3,1,3);
hEcho2 = plot(0,0,'LineWidth',1.5);
xlabel('Sample');
ylabel('Voltage (V)');
title('Sensor 2 Echo');
ylim([-0.5 5.5]);
grid on;

write(myDaq, [false false]);

while ishandle(hEcho1)

    trigger1Log = [];
    trigger2Log = [];
    echo1Log = [];
    echo2Log = [];

    for k = 1:repetitions

        % Sensor 1 trigger
        write(myDaq, [true false]);
        logSample(1, 0);

        pause(pulseLength);

        write(myDaq, [false false]);
        logSample(0, 0);

        tic;
        while toc < pauseBetweenTriggers
            logSample(0, 0);
        end

        % Sensor 2 trigger
        write(myDaq, [false true]);
        logSample(0, 1);

        pause(pulseLength);

        write(myDaq, [false false]);
        logSample(0, 0);

        tic;
        while toc < pauseBetweenTriggers
            logSample(0, 0);
        end
    end

    % Extra quiet time at end
    tic;
    while toc < pauseBetweenTriggers
        logSample(0, 0);
    end

    widths1 = getEchoWidths(echo1Log, echoThresh, repetitions);
    widths2 = getEchoWidths(echo2Log, echoThresh, repetitions);

    cm1 = widths1 / 5.8;
    cm2 = widths2 / 5.8;

    fprintf('Sensor 1: %.1f %.1f %.1f cm | Sensor 2: %.1f %.1f %.1f cm\n', ...
        cm1(1), cm1(2), cm1(3), cm2(1), cm2(2), cm2(3));

    x = 1:numel(echo1Log);

    set(hTrig1, 'XData', x, 'YData', trigger1Log);
    set(hTrig2, 'XData', x, 'YData', trigger2Log);

    set(hEcho1, 'XData', x, 'YData', echo1Log);
    set(hEcho2, 'XData', x, 'YData', echo2Log);

    drawnow;
end

write(myDaq, [false false]);


function logSample(trig1, trig2)
    d = evalin('caller', 'read(myDaq)');

    assignin('caller', 'trigger1Log', [evalin('caller','trigger1Log'); trig1]);
    assignin('caller', 'trigger2Log', [evalin('caller','trigger2Log'); trig2]);

    assignin('caller', 'echo1Log', [evalin('caller','echo1Log'); d{1,1}]);
    assignin('caller', 'echo2Log', [evalin('caller','echo2Log'); d{1,2}]);
end


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