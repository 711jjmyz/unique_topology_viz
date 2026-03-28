clc; clear; close all;

% ===== 用户输入 =====
A = [0 1 1 0;
     1 0 1 0;
     1 1 0 1;
     0 0 1 0];

a5 = [0; 0; 1; 0];

% ===== 流程调用 =====
fprintf('===== Step 1: 构建约束 =====\n');
[Aeq, beq, Aineq, bineq, lb, ub, intcon] = build_constraints(A, a5);

fprintf('===== Step 2: ILP求解 =====\n');
[x_sol, is_unique] = solve_topology(Aeq, beq, Aineq, bineq, lb, ub, intcon);

fprintf('===== Step 3: 解析拓扑 =====\n');
[balls, rods] = parse_topology(x_sol, A);

fprintf('===== Step 4: 可视化 =====\n');
visualize_topology(balls, rods, A);

fprintf('===== Step 5: 输出报告 =====\n');
print_report(balls, rods, is_unique);