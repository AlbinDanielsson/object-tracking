dq = daq("ni");


addoutput(dq, "myDAQ1", "port0/line0", "Digital");


addinput(dq, "myDAQ1", "ai0", "Voltage");


write(dq, 1);
pause(0.00001)
write(dq, 0);

data = read(dq, seconds(0.05));