clear all
clc

s1 = 52;
s2 = 37;

l = 15;

pos = triangle(s1, s2, l);

%control
%d = norm(p2 - p1);
a = [-l/2, 0];
b = [l/2, 0];

testA = norm(a - pos);
testB = norm(b - pos);

fprintf('test %d, %d', pos(1), pos(2));