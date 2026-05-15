myDaq = daq("ni");
myDaq.Rate = 100000;   % 100 kHz → 10 µs per sample

addoutput(myDaq, "myDAQ1", "ao0", "Voltage");
addinput(myDaq,  "myDAQ1", "ai0", "Voltage");

% Create waveform: 1 sample high (10 µs), rest low
pulse = [5; zeros(4999,1)];   % total 5000 samples = 50 ms

% Start acquisition + output together
[data, time] = readwrite(myDaq, pulse);

echo = data{:,1};
t = seconds(data.Time);

% Thresholding
threshold = 2.5;
echoDigital = echo > threshold;

% Edge detection
idxRise = find(diff(echoDigital) == 1, 1, "first") + 1;
idxFall = find(diff(echoDigital) == -1 & (1:length(diff(echoDigital)))' > idxRise, 1, "first") + 1;

if isempty(idxRise) || isempty(idxFall)
    disp("No echo detected");
else
    echoTime = t(idxFall) - t(idxRise);
    distance_cm = echoTime * 1e6 / 58;

    fprintf("Echo time: %.1f us\n", echoTime*1e6);
    fprintf("Distance: %.2f cm\n", distance_cm);
end