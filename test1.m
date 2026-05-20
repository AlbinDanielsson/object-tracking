clear all
clc

r1 = 30;
r2 = 20;
l = 5;

angle = flatObjectAngle(r1, r2, l);
angle = angle * (180 / pi);