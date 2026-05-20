function a = flatObjectAngle(r1, r2, l)
    %Assume r1 is to the systems right
    delta_r = r1 - r2;
    a = atan2(delta_r, l);
end

