% =========================================================
%  FreeSN Ground-Truth 批量测试
%
%  流程：
%    1. 随机生成物理结构（球节点 + 杆连接），作为 ground truth
%    2. 从物理结构推导出 A 矩阵和 a 向量
%    3. 跑算法 Step1~3（build -> solve -> parse）
%    4. 将算法输出的物理结构与 ground truth 对比
%    5. 统计正确率，保存失败案例
%
%  用法：直接运行 batch_test()
% =========================================================

function batch_test()

    % ======== 参数设置 ========
    NUM_SAMPLES    = 3000;
    N_MIN          = 10;     % strut 数量下限
    N_MAX          = 20;     % strut 数量上限
    MAX_PER_NODE   = 12;     % 每个球最多连接的 strut 数
    P_CONNECT_END1 = 0.5;    % strut 第二端连接的概率
    LOG_FILE       = 'batch_test_log.txt';

    % ======== 初始化统计 ========
    n_pass       = 0;
    n_fail_build = 0;
    n_fail_solve = 0;
    n_fail_parse = 0;
    n_fail_match = 0;  % ground truth 不匹配
    n_gen_fail   = 0;

    fail_cases = {};

    fprintf('========================================\n');
    fprintf('  FreeSN Ground-Truth 批量测试\n');
    fprintf('  目标样本数 : %d\n', NUM_SAMPLES);
    fprintf('  strut 范围 : %d ~ %d\n', N_MIN, N_MAX);
    fprintf('========================================\n\n');

    total_time = tic;
    count = 0;

    while count < NUM_SAMPLES

        % ---- Step 0: 生成物理结构（ground truth）----
        n = randi([N_MIN, N_MAX]);
        [gt, valid] = generate_physical_structure(n, MAX_PER_NODE, P_CONNECT_END1);
        if ~valid
            n_gen_fail = n_gen_fail + 1;
            continue;
        end
        count = count + 1;

        % 从物理结构推导 A 和 a
        A = gt.A;
        a = gt.a;

        % ---- 打印进度 ----
        if mod(count, 100) == 0
            elapsed   = toc(total_time);
            pass_rate = n_pass / count * 100;
            fprintf('[%4d/%d]  通过率: %5.1f%%  用时: %.1fs\n', ...
                    count, NUM_SAMPLES, pass_rate, elapsed);
        end

        % ---- Step 1: 构建约束 ----
        try
            [Aeq, beq, Aineq, bineq, lb, ub, intcon] = build_constraints(A);
        catch ME
            n_fail_build = n_fail_build + 1;
            fail_cases = append_case(fail_cases, gt, 'build_constraints异常', ME.message);
            continue;
        end

        % ---- Step 2: ILP 求解 ----
        try
            [x_sol, is_unique] = solve_topology(Aeq, beq, Aineq, bineq, lb, ub, intcon, A);
        catch ME
            n_fail_solve = n_fail_solve + 1;
            fail_cases = append_case(fail_cases, gt, 'solve_topology异常', ME.message);
            continue;
        end

        if isempty(x_sol)
            n_fail_solve = n_fail_solve + 1;
            fail_cases = append_case(fail_cases, gt, 'ILP无解', '');
            continue;
        end
        if ~is_unique
            n_fail_solve = n_fail_solve + 1;
            fail_cases = append_case(fail_cases, gt, '解不唯一', '');
            continue;
        end

        % ---- Step 3: 解析拓扑 ----
        try
            [balls, rods] = parse_topology(x_sol, A, a);
        catch ME
            n_fail_parse = n_fail_parse + 1;
            fail_cases = append_case(fail_cases, gt, 'parse_topology异常', ME.message);
            continue;
        end

        % ---- Step 4: 与 ground truth 对比 ----
        [ok, reason] = compare_with_groundtruth(rods, gt);
        if ok
            n_pass = n_pass + 1;
        else
            n_fail_match = n_fail_match + 1;
            fail_cases = append_case(fail_cases, gt, '与ground truth不匹配', reason);
        end
    end

    % ======== 打印最终报告 ========
    elapsed_total = toc(total_time);
    n_fail_total  = n_fail_build + n_fail_solve + n_fail_parse + n_fail_match;

    fprintf('\n========================================\n');
    fprintf('  批量测试完成\n');
    fprintf('========================================\n');
    fprintf('总测试样本数       : %d\n', NUM_SAMPLES);
    fprintf('----------------------------------------\n');
    fprintf('通过               : %d  (%.1f%%)\n', n_pass,        n_pass/NUM_SAMPLES*100);
    fprintf('失败（合计）       : %d  (%.1f%%)\n', n_fail_total,  n_fail_total/NUM_SAMPLES*100);
    fprintf('  build异常        : %d\n', n_fail_build);
    fprintf('  ILP无解/非唯一   : %d\n', n_fail_solve);
    fprintf('  parse异常        : %d\n', n_fail_parse);
    fprintf('  结构不匹配       : %d\n', n_fail_match);
    fprintf('----------------------------------------\n');
    fprintf('样本生成额外尝试   : %d\n', n_gen_fail);
    fprintf('总用时             : %.2f 秒\n', elapsed_total);
    fprintf('平均每样本         : %.3f 秒\n', elapsed_total / NUM_SAMPLES);
    fprintf('========================================\n');

    if ~isempty(fail_cases)
        save('fail_cases.mat', 'fail_cases');
        write_log(fail_cases, LOG_FILE);
        fprintf('\n失败案例已保存: fail_cases.mat + %s (%d 个)\n', LOG_FILE, length(fail_cases));
    else
        fprintf('\n所有样本全部通过！\n');
    end
end


% =========================================================
%  生成物理结构（ground truth）
%
%  gt 结构体包含：
%    gt.n              : strut 数量
%    gt.n_balls        : 球节点数量
%    gt.ball_of_ep     : n×2，ball_of_ep(i,k) = strut i 端点k连接的球编号（0=无球）
%    gt.struts_of_ball : cell数组，struts_of_ball{b} = 连在球b上的strut列表
%    gt.A              : 从物理结构推导的连接矩阵
%    gt.a              : 从物理结构推导的a向量
% =========================================================
function [gt, valid] = generate_physical_structure(n, max_per_node, p_connect_end1)
    valid = false;
    gt    = struct();

    % ball_of_ep(i,k): strut i 的端点 k 连接的球编号（0=未连接）
    ball_of_ep = zeros(n, 2);

    % struts_of_ball{b}: 连在球 b 上的 strut 列表
    struts_of_ball = {};
    n_balls = 0;

    % ---- strut 1：两端各连一个新球 ----
    n_balls = n_balls + 1; ball_of_ep(1,1) = n_balls;
    struts_of_ball{n_balls} = [1];
    n_balls = n_balls + 1; ball_of_ep(1,2) = n_balls;
    struts_of_ball{n_balls} = [1];

    % ---- strut 2 ~ n ----
    for i = 2:n
        % 端点1：必须连一个已有球（保证连通）
        cands = find_candidates(struts_of_ball, 0, max_per_node);
        if isempty(cands)
            return;
        end
        b1 = cands(randi(length(cands)));
        ball_of_ep(i, 1) = b1;
        struts_of_ball{b1} = [struts_of_ball{b1}, i];

        % 端点2：以概率 p 决定是否连接
        if rand() < p_connect_end1
            cands2 = find_candidates(struts_of_ball, b1, max_per_node);
            if isempty(cands2) || (rand() < 0.3 && n_balls < n * 2)
                % 新建球
                n_balls = n_balls + 1;
                struts_of_ball{n_balls} = [i];
                ball_of_ep(i, 2) = n_balls;
            else
                b2 = cands2(randi(length(cands2)));
                ball_of_ep(i, 2) = b2;
                struts_of_ball{b2} = [struts_of_ball{b2}, i];
            end
        end
        % else: 端点2不连接，ball_of_ep(i,2) 保持 0
    end

    % ---- 从物理结构推导 A 矩阵 ----
    % A(i,j) = 1 当且仅当 strut i 和 j 共享同一个球
    A = zeros(n, n);
    for b = 1:n_balls
        members = struts_of_ball{b};
        for p = 1:length(members)
            for q = p+1:length(members)
                u = members(p); v = members(q);
                A(u,v) = 1;
                A(v,u) = 1;
            end
        end
    end
    A = A - diag(diag(A));  % 保证对角线为0

    % ---- 推导 a 向量 ----
    a = zeros(n, 1);
    for i = 1:n
        if ball_of_ep(i,1) > 0 && ball_of_ep(i,2) > 0
            a(i) = 1;
        end
    end

    % ---- 合法性检查 ----
    for i = 1:n
        % 不允许两端都未连接
        if ball_of_ep(i,1) == 0 && ball_of_ep(i,2) == 0
            return;
        end
    end

    % ---- 打包 ground truth ----
    gt.n              = n;
    gt.n_balls        = n_balls;
    gt.ball_of_ep     = ball_of_ep;     % n×2
    gt.struts_of_ball = struts_of_ball; % cell{b}
    gt.A              = A;
    gt.a              = a;

    valid = true;
end


% =========================================================
%  与 ground truth 对比
%
%  核心思路：
%    两个物理结构"等价"当且仅当：
%    对每一对 (strut i, strut j)，
%      ground truth 中 i 和 j 共享球  <=>  算法输出中 i 和 j 共享球
%    即两者推导出的 A 矩阵完全相同。
%
%  注意：球的编号不需要一致（只需拓扑等价），
%        所以我们通过重新从 rods 推导 A' 来对比。
% =========================================================
function [ok, reason] = compare_with_groundtruth(rods, gt)
    ok = true;
    reason = '';
    N = gt.n;

    % 从算法输出的 rods 重新推导 A'
    % A'(i,j) = 1 当且仅当 rods.ball1/ball2 中 strut i 和 j 共享同一个非零球编号
    A_pred = zeros(N, N);
    for i = 1:N
        for j = i+1:N
            balls_i = [rods.ball1(i), rods.ball2(i)];
            balls_j = [rods.ball1(j), rods.ball2(j)];
            balls_i = balls_i(balls_i > 0);
            balls_j = balls_j(balls_j > 0);
            if ~isempty(intersect(balls_i, balls_j))
                A_pred(i,j) = 1;
                A_pred(j,i) = 1;
            end
        end
    end

    % 对比 A_pred 与 ground truth 的 A
    if ~isequal(A_pred, gt.A)
        ok = false;
        diff = gt.A - A_pred;
        n_miss  = sum(sum(diff > 0)) / 2;  % ground truth有但算法没有
        n_extra = sum(sum(diff < 0)) / 2;  % 算法多出来的
        reason = sprintf('A矩阵不匹配: 漏掉%d条连接, 多出%d条连接', n_miss, n_extra);
        return;
    end

    % 对比 a 向量
    % 算法输出的 a': ball1>0 且 ball2>0 则 a'(i)=1
    a_pred = zeros(N, 1);
    for i = 1:N
        if rods.ball1(i) > 0 && rods.ball2(i) > 0
            a_pred(i) = 1;
        end
    end

    if ~isequal(a_pred, gt.a)
        ok = false;
        reason = sprintf('a向量不匹配: %d个strut的端点连接状态有误', sum(a_pred ~= gt.a));
    end
end


% =========================================================
%  辅助：找候选球节点（未超容量且不是排除节点）
% =========================================================
function candidates = find_candidates(struts_of_ball, exclude_ball, max_per_node)
    candidates = [];
    for k = 1:length(struts_of_ball)
        if k ~= exclude_ball && length(struts_of_ball{k}) < max_per_node
            candidates = [candidates, k];
        end
    end
end


% =========================================================
%  记录失败案例
% =========================================================
function fail_cases = append_case(fail_cases, gt, reason, detail)
    entry.gt     = gt;
    entry.reason = reason;
    entry.detail = detail;
    fail_cases{end+1} = entry;
end


% =========================================================
%  写失败日志
% =========================================================
function write_log(fail_cases, filename)
    fid = fopen(filename, 'w');
    fprintf(fid, 'FreeSN Ground-Truth 批量测试失败日志\n');
    fprintf(fid, '生成时间: %s\n\n', datestr(now));
    for i = 1:length(fail_cases)
        c = fail_cases{i};
        fprintf(fid, '==== 失败案例 #%d  (n=%d struts, %d balls) ====\n', ...
                i, c.gt.n, c.gt.n_balls);
        fprintf(fid, '原因 : %s\n', c.reason);
        if ~isempty(c.detail)
            fprintf(fid, '详情 : %s\n', c.detail);
        end
        fprintf(fid, 'a = %s\n', mat2str(c.gt.a'));
        fprintf(fid, 'A =\n');
        for r = 1:size(c.gt.A, 1)
            fprintf(fid, '  %s\n', mat2str(c.gt.A(r,:)));
        end
        fprintf(fid, 'ball_of_ep =\n');
        for r = 1:c.gt.n
            fprintf(fid, '  strut%2d: 端点1->球%d  端点2->球%d\n', ...
                    r, c.gt.ball_of_ep(r,1), c.gt.ball_of_ep(r,2));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end
