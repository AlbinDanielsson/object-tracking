clear; clc; close all;

myDaq = daq("ni");

% Digital trigger output
addoutput(myDaq, "myDAQ1", "port0/line0", "Digital");


write(myDaq, false);

while true
    pause(1);

    write(myDaq, true);

    pause(1);

    write(myDaq, false);
end

write(myDaq, false);