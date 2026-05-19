clear; clc; close all;

myDaq = daq("ni");

% Digital trigger output
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");

%Digital input
addinput(myDaq, "myDAQ1", "port0/line1", "Digital");


write(myDaq, false);

while true
    pause(1);

    write(myDaq, true);

    % Read input
    in = read(myDaq, "OutputFormat", "logical");
    disp("Input state: " + in)

    pause(1);

    write(myDaq, false);

    % Read again
    in = read(myDaq, "OutputFormat", "logical");
    disp("Input state: " + in);
end

write(myDaq, false);