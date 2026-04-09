function [Aeq, beq, Aineq, bineq, lb, ub, intcon] = build_constraints(A)

N = size(A, 1);       % 杆数
nVars = 4 * N * N;    % v(i,k,j,n) 变量总数

if size(A, 2) ~= N
    error('A must be an N-by-N square matrix.');
end


% 索引函数: v(i,k,j,n), i,j=1..N; k,n=1,2
idx = @(i,k,j,n) (i-1)*(4*N) + (k-1)*(2*N) + (j-1)*2 + n;

Aeq   = []; beq   = [];
Aineq = []; bineq = [];

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
for i = 1:N
    for j = 1:N
        if i == j
            continue;
        end
        row = zeros(1, nVars);
        for k = 1:2
            for n = 1:2
                row(idx(i,k,j,n)) = 1;
            end
        end
        Aeq = [Aeq; row];
        beq = [beq; A(i,j)];
    end
end

%% Constraint 3: transitivity linearization
% v(i,k,j,n) + v(i,k,m,p) - v(j,n,m,p) <= 1
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
                        row = zeros(1, nVars);
                        row(idx(i,k,j,n)) = 1;
                        row(idx(i,k,m,p)) = 1;
                        row(idx(j,n,m,p)) = -1;
                        Aineq = [Aineq; row];
                        bineq = [bineq; 1];
                    end
                end
            end
        end
    end
end

%% Constraint 4: symmetry v(i,k,j,n) = v(j,n,i,k)
for i = 1:N
    for k = 1:2
        for j = 1:N
            if j <= i
                continue;
            end
            for n = 1:2
                row = zeros(1, nVars);
                row(idx(i,k,j,n)) = 1;
                row(idx(j,n,i,k)) = -1;
                Aeq = [Aeq; row];
                beq = [beq; 0];
            end
        end
    end
end

%% Constraint 5: symmetry breaking
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

    row = zeros(1, nVars);
    for n = 1:2
        row(idx(i,2,j_min,n)) = 1;
        row(idx(i,1,j_min,n)) = -1;
    end
    Aineq = [Aineq; row];
    bineq = [bineq; 0];
end

intcon = 1:nVars;
end
