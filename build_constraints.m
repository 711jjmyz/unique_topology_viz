function [Aeq, beq, Aineq, bineq, lb, ub, intcon] = build_constraints(A)

N = size(A, 1);       % 杆数
nVars = 4 * N * N;    % v(i,k,j,n) 变量总数

if size(A, 2) ~= N
    error('A must be an N-by-N square matrix.');
end


% 索引函数: v(i,k,j,n), i,j=1..N; k,n=1,2
idx = @(i,k,j,n) (i-1)*(4*N) + (k-1)*(2*N) + (j-1)*2 + n;

Aeq   = sparse(0, nVars);
beq   = zeros(0, 1);
Aineq = sparse(0, nVars);
bineq = zeros(0, 1);

%% Constraint 1: no self-loop v(i,k,i,n)=0 via bounds
lb = zeros(nVars, 1);
ub = ones(nVars, 1);
for i = 1:N
    for k = 1:2
        for n = 1:2
            ub(idx(i,k,i,n)) = 0;
        end
    end
end

%% Constraint 2: mapping to A
% sum_{k,n} v(i,k,j,n) = A(i,j), for i ~= j
nC2 = N * (N - 1);
I2 = zeros(4 * nC2, 1);
J2 = zeros(4 * nC2, 1);
V2 = ones(4 * nC2, 1);
beq2 = zeros(nC2, 1);
r = 0;
t = 0;
for i = 1:N
    for j = 1:N
        if i == j
            continue;
        end
        r = r + 1;
        beq2(r) = A(i,j);
        for k = 1:2
            for n = 1:2
                t = t + 1;
                I2(t) = r;
                J2(t) = idx(i,k,j,n);
            end
        end
    end
end
Aeq2 = sparse(I2, J2, V2, nC2, nVars);

%% Constraint 3: transitivity linearization
% v(i,k,j,n) + v(i,k,m,p) - v(j,n,m,p) <= 1
nC3 = 8 * N * (N - 1) * (N - 2);
I3 = zeros(3 * nC3, 1);
J3 = zeros(3 * nC3, 1);
V3 = zeros(3 * nC3, 1);
r = 0;
t = 0;
for i = 1:N
    for k = 1:2
        for j = 1:N
            if j == i
                continue;
            end
            for n = 1:2
                for m = 1:N
                    if m == i || m == j
                        continue;
                    end
                    for p = 1:2
                        r = r + 1;
                        t = t + 1;
                        I3(t) = r;
                        J3(t) = idx(i,k,j,n);
                        V3(t) = 1;
                        t = t + 1;
                        I3(t) = r;
                        J3(t) = idx(i,k,m,p);
                        V3(t) = 1;
                        t = t + 1;
                        I3(t) = r;
                        J3(t) = idx(j,n,m,p);
                        V3(t) = -1;
                    end
                end
            end
        end
    end
end
Aineq3 = sparse(I3, J3, V3, nC3, nVars);
bineq3 = ones(nC3, 1);

%% Constraint 4: symmetry v(i,k,j,n) = v(j,n,i,k)
nC4 = 2 * N * (N - 1);
I4 = zeros(2 * nC4, 1);
J4 = zeros(2 * nC4, 1);
V4 = zeros(2 * nC4, 1);
beq4 = zeros(nC4, 1);
r = 0;
t = 0;
for i = 1:N
    for k = 1:2
        for j = 1:N
            if j <= i
                continue;
            end
            for n = 1:2
                r = r + 1;
                t = t + 1;
                I4(t) = r;
                J4(t) = idx(i,k,j,n);
                V4(t) = 1;
                t = t + 1;
                I4(t) = r;
                J4(t) = idx(j,n,i,k);
                V4(t) = -1;
            end
        end
    end
end
Aeq4 = sparse(I4, J4, V4, nC4, nVars);

%% Constraint 5: symmetry breaking
I5 = zeros(4 * N, 1);
J5 = zeros(4 * N, 1);
V5 = zeros(4 * N, 1);
bineq5 = zeros(N, 1);
r = 0;
t = 0;
for i = 1:N
    j_min = 0;
    for j = 1:N
        if j ~= i && A(i,j) >= 1
            j_min = j;
            break;
        end
    end
    if j_min == 0
        continue;
    end

    r = r + 1;
    for n = 1:2
        t = t + 1;
        I5(t) = r;
        J5(t) = idx(i,2,j_min,n);
        V5(t) = 1;
        t = t + 1;
        I5(t) = r;
        J5(t) = idx(i,1,j_min,n);
        V5(t) = -1;
    end
end
Aineq5 = sparse(I5(1:t), J5(1:t), V5(1:t), r, nVars);
bineq5 = bineq5(1:r);

Aeq = [Aeq2; Aeq4];
beq = [beq2; beq4];
Aineq = [Aineq3; Aineq5];
bineq = [bineq3; bineq5];

intcon = 1:nVars;
end
