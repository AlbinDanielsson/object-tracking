dq = daq("ni");
dq.Rate = 100000;   % 100 kHz gives 10 us timing resolution

% Connections:
% TRIG -> myDAQ port0/line0
% ECHO -> myDAQ port0/line1
% GND  -> myDAQ GND
addoutput(dq, "myDAQ1", "port0/line0", "Digital");
addinput(dq,  "myDAQ1", "port0/line1", "Digital");

% Make sure trigger starts low
write(dq, 0);
pause(0.1);

% Start acquisition first so the echo is not missed
start(dq, "Duration", seconds(0.05));

% Send 10 us trigger pulse
write(dq, 1);
pause(10e-6);
write(dq, 0);

% Collect recorded echo
data = read(dq, "all");

t = seconds(data.Time);
echo = data{:,1};

% Find rising and falling edges of echo
idxRise = find(diff(echo) == 1, 1, "first") + 1;
idxFall = find(diff(echo) == -1 & (1:length(diff(echo)))' > idxRise, 1, "first") + 1;

if isempty(idxRise) || isempty(idxFall)
    disp("No echo detected");
else
    echoTime = t(idxFall) - t(idxRise);      % seconds
    distance_cm = echoTime * 1e6 / 58;       % datasheet formula

    fprintf("Echo time: %.1f us\n", echoTime*1e6);
    fprintf("Distance: %.2f cm\n", distance_cm);
end