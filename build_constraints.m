function [Aeq, beq, Aineq, bineq, lb, ub, intcon] = build_constraints(A, a5)


N = 4;       % 杆数

nVars = 64;  % 变量总数，每个杆有两端，每一端有和其他3根杆（以及自身）的8种连接关系，一共4*2*8=64

% 索引函数
% b把64个连接变量映射为 v(i,k,j,n)，其中 i,j=1..4（杆编号），k=1,2（连接类型），n=1,2（连接编号）
idx = @(i,k,j,n) (i-1)*16 + (k-1)*8 + (j-1)*2 + n;

Aeq   = []; beq   = [];
Aineq = []; bineq = [];

%% ---- 约束1：无自环 v(i,k,i,n) = 0 ----
% 直接通过上下界实现：对所有 i=j 的变量，lb=ub=0
lb = zeros(nVars, 1);
ub = ones(nVars, 1);
for i = 1:N
    for k = 1:2
        for n = 1:2
            ub(idx(i,k,i,n)) = 0; % 强制为0
        end
    end
end

%% ---- 约束2：矩阵A映射等式 ----
% sum_{k,n} v(i,k,j,n) = A(i,j), 对所有 i≠j
% 实现16个等式约束
for i = 1:N
    for j = 1:N
        if i == j 
            continue; 
        end
        row = zeros(1, nVars);
        for k = 1:2
            for n = 1:2
                row(idx(i,k,j,n)) = 1; %只有特定4个等于1
            end
        end
        Aeq   = [Aeq;   row];
        beq   = [beq;   A(i,j)];
    end
end

%% ---- 约束3：共铰传递性（线性化） ----
% v(i,k,j,n) + v(i,k,m,p) - v(j,n,m,p) <= 1
% 对所有 i,k,j,n,m,p（j≠m, j≠i, m≠i）
for i = 1:N
    for k = 1:2
        for j = 1:N
            if j == i 
                continue; 
            end
            for n = 1:2
                for m = 1:N
                    if m == i || m == j, continue; end
                    for p = 1:2
                        row = zeros(1, nVars);
                        row(idx(i,k,j,n)) =  1;
                        row(idx(i,k,m,p)) =  1;
                        row(idx(j,n,m,p)) = -1;
                        Aineq = [Aineq; row];
                        bineq = [bineq; 1]; %求解器会自动变成 <= 形式：v(i,k,j,n) + v(i,k,m,p) - v(j,n,m,p) <= 1
                    end
                end
            end
        end
    end
end

%% ---- 约束4：双向对称等式 ----
% v(i,k,j,n) = v(j,n,i,k)   
% 自由变量数量减少一半
for i = 1:N
    for k = 1:2
        for j = 1:N
            if j <= i, continue; end  % 避免重复
            for n = 1:2
                row = zeros(1, nVars);
                row(idx(i,k,j,n)) =  1;
                row(idx(j,n,i,k)) = -1;
                Aeq   = [Aeq;   row];
                beq   = [beq;   0];
            end
        end
    end
end

%% ---- 约束5：对称性破缺 ----
% 对每根杆i，找j_min，强制 sum_n v(i,1,j_min,n) >= sum_n v(i,2,j_min,n)
for i = 1:N
    % 找与杆i相连的编号最小的杆
    j_min = 0;
    for j = 1:N
        if j ~= i && A(i,j) >= 1
            j_min = j;
            break;
        end
    end
    if j_min == 0, continue; end
    
    % sum_n v(i,1,j_min,n) - sum_n v(i,2,j_min,n) >= 0
    % 转为 <= 形式：sum_n v(i,2,j_min,n) - sum_n v(i,1,j_min,n) <= 0
    row = zeros(1, nVars);
    for n = 1:2
        row(idx(i, 2, j_min, n)) =  1;
        row(idx(i, 1, j_min, n)) = -1;
    end
    Aineq = [Aineq; row];
    bineq = [bineq; 0];
end

intcon = 1:nVars;  % 全部为整数变量（0或1）
end