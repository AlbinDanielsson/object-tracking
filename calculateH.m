function H = calculateH(r1, r2, angle, l)
    %H = [
    %   ∂r1/∂x   ∂r1/∂y   ∂r1/∂theta
    %   ∂r2/∂x   ∂r2/∂y   ∂r2/∂theta
    %]
    %TODO, make sure r2 and r2 are not mixed up!
    H = [0, 1, -cos(angle)^2/l;
        0, 1, cos(angle)^2/l];
end