function [x_sol, is_unique] = solve_topology(Aeq, beq, Aineq, bineq, lb, ub, intcon)

nVars = 64; %变量总数

f = zeros(nVars, 1);  % 无目标函数（纯可行解求解）

options = optimoptions('intlinprog', 'Display', 'off');

%% 第一次求解
[x1, ~, exitflag1] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub, options);

if exitflag1 <= 0
    error('无解！');
end

x_sol = round(x1);  % 消除浮点误差
fprintf('找到第一个拓扑解。\n');

%% 第二次求解（验证唯一性）
% 添加屏蔽约束：禁止解 = x_sol
S1 = find(x_sol == 1);
S0 = find(x_sol == 0);

new_row = zeros(1, nVars);
new_row(S1) =  1;
new_row(S0) = -1;
new_b = length(S1) - 1;

Aineq2 = [Aineq; new_row];
bineq2 = [bineq; new_b];

[~, ~, exitflag2] = intlinprog(f, intcon, Aineq2, bineq2, Aeq, beq, lb, ub, options);

if exitflag2 <= 0
    is_unique = true;
    fprintf('唯一\n');
else
    is_unique = false;
    fprintf('不唯一\n');
end
end