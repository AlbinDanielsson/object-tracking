myDaq = daq("ni");
myDaq.Rate = 100000;   % 100 kHz → 10 µs per sample

addoutput(myDaq, "myDAQ1", "ao0", "Voltage");
addinput(myDaq,  "myDAQ1", "ai0", "Voltage");

cycleLength = 40000;
repetitions = 3;
% Create waveform: 1 sample high (10 µs), rest low
pulse = [zeros(cycleLength -1 ,1); 3];   % total 5000 samples = 50 ms
pulse = repmat(pulse(:).', 1, repetitions)';
pulse = [pulse; zeros(cycleLength, 1)];

% Start acquisition + output together
[data, time] = readwrite(myDaq, pulse);

echo = data{:,1};
t = seconds(data.Time);

% Thresholding
threshold = 2.5;
echoDigital = echo > threshold;

% Trigger plot
subplot(2,1,1);
hTrigger = plot(t*1000, pulse, 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Voltage (V)');
title('Trigger Signal');
ylim([-0.5 5.5]);
grid on;

% Echo plot
subplot(2,1,2);
hEcho = plot(t*1000, zeros(size(pulse)), 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Voltage (V)');
title('Echo Signal');
ylim([-0.5 5.5]);
grid on;

echoThresh = 2;
echoWidths = zeros(repetitions, 1);
eStart = 0;
eEnd = 0;
bEcho = false;
echoIndex = 1;

while ishandle(hEcho)

    % Send trigger and acquire echo
    data = readwrite(myDaq, pulse);

    echo = data{:,1};

    echoIndex = 1;
    %loop through data and find the width of each echo
    for i = 1:1:numel(data)
        if bEcho == false
            if echo(i) > echoThresh
                bEcho = true;
                eStart = i;
            end
        else
            if echo(i) < echoThresh
                bEcho = false;
                eEnd = i;
                echoWidths(echoIndex) = eEnd - eStart;
                echoIndex = echoIndex + 1;
            end
        end

    end
    
    cm = round(echoWidths/5.8, 1);
    fprintf('d1 = %.1f cm, d2 = %.1f cm, d3 = %.1f cm\n', cm);

    % Update echo plot
    set(hEcho, 'YData', echo);

    drawnow;

end