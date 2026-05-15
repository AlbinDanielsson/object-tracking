myDaq = daq("ni");
myDaq.Rate = 100000;   % 100 kHz (10 µs resolution)

% Add analog channels
addoutput(myDaq, "myDAQ1", "ao0", "Voltage");   % Analog output
addinput(myDaq,  "myDAQ1", "ai0", "Voltage");   % Analog input

% Initialize output to 0 V
write(myDaq, 0);
pause(0.1);

% Start acquisition (non-blocking)
start(myDaq, "Duration", seconds(0.05));

% Generate ~10 µs trigger pulse (e.g., 5 V)
write(myDaq, 5);
pause(10e-6);
write(myDaq, 0);

% Read captured data
data = read(myDaq, "all");

t = seconds(data.Time);
echo = data{:,1};

% Convert analog signal to digital-like using threshold
threshold = 2.5;   % midpoint (adjust based on your signal)
echoDigital = echo > threshold;

% Detect edges
idxRise = find(diff(echoDigital) == 1, 1, "first") + 1;
idxFall = find(diff(echoDigital) == -1 & (1:length(diff(echoDigital)))' > idxRise, 1, "first") + 1;

if isempty(idxRise) || isempty(idxFall)
    disp("No echo detected");
else
    echoTime = t(idxFall) - t(idxRise);   % seconds
    distance_cm = echoTime * 1e6 / 58;

    fprintf("Echo time: %.1f us\n", echoTime*1e6);
    fprintf("Distance: %.2f cm\n", distance_cm);
end