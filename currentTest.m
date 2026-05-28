clear;
clc;

% Create DAQ object
myDaq = daq("ni");

% Add analog output channel
addoutput(myDaq, "myDAQ1", "ao0", "Voltage");

% Constant output voltage
triggerVoltage = 1;

% Write voltage to output
write(myDaq, triggerVoltage);

disp("Output held at 3 V");

% Keep script running so output stays active
%pause(inf);

write(myDaq, 0);