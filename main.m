clc; clear; close all;

% 正八面体构型连接矩阵 A（12根杆）
% A 为 12x12 杆-杆邻接矩阵：A(i,j)=1 表示第 i、j 根杆共享一个端点

A = [
% R1  R2  R3  R4  R5  R6  R7  R8  R9  R10 R11 R12
  0,  1,  1,  0,  0,  0,  0,  0,  1,  1,  0,  0; % R1 (球1-2)
  1,  0,  0,  1,  0,  0,  0,  0,  0,  1,  1,  0; % R2 (球2-3)
  1,  0,  0,  1,  0,  0,  0,  0,  1,  0,  0,  1; % R3 (球3-4)
  0,  1,  1,  0,  0,  0,  0,  0,  0,  0,  1,  1; % R4 (球4-1)
  0,  0,  0,  0,  0,  1,  0,  1,  1,  1,  0,  0; % R5 (球1-5)
  0,  0,  0,  0,  1,  0,  1,  0,  0,  1,  1,  0; % R6 (球2-5)
  0,  0,  0,  0,  0,  1,  0,  1,  0,  0,  1,  1; % R7 (球3-5)
  0,  0,  0,  0,  1,  0,  1,  0,  1,  0,  0,  1; % R8 (球4-5)
  1,  0,  1,  0,  1,  0,  0,  1,  0,  0,  0,  0; % R9 (球1-6)
  1,  1,  0,  0,  1,  1,  0,  0,  0,  0,  0,  0; % R10(球2-6)
  0,  1,  0,  1,  0,  1,  1,  0,  0,  0,  0,  0; % R11(球3-6)
  0,  0,  1,  1,  0,  0,  1,  1,  0,  0,  0,  0; % R12(球4-6)
];

a = ones(12, 1);
% ===== 流程调用 =====
fprintf('===== Step 1: 构建约束 =====\n');
[Aeq, beq, Aineq, bineq, lb, ub, intcon] = build_constraints(A);

fprintf('===== Step 2: ILP求解 =====\n');
[x_sol, is_unique] = solve_topology(Aeq, beq, Aineq, bineq, lb, ub, intcon, A);

fprintf('===== Step 3: 解析拓扑 =====\n');
[balls, rods] = parse_topology(x_sol, A, a);

fprintf('===== Step 4: 可视化 =====\n');
visualize_topology(balls, rods, A);

fprintf('===== Step 5: 输出报告 =====\n');
print_report(balls, rods, is_unique);
