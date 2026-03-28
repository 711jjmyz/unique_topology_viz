function visualize_topology(balls, rods, A)

N_balls = balls.count;
N_rods  = rods.count;

%% 用弹簧力布局计算三维坐标
% 初始化随机坐标
rng(42);
pos = randn(N_balls, 3);

% 弹簧力迭代（简单实现）
for iter = 1:500
    force = zeros(N_balls, 3);
    
    % 相连节点之间的引力
    for r = 1:N_rods
        b1 = rods.ball1(r);
        b2 = rods.ball2(r);
        % 跳过任一端没有小球编号的杆（半连接或无连接的杆在力计算中不参与）
        if b1 == 0 || b2 == 0, continue; end
        if b1 == b2, continue; end  % 悬空杆（两端属于同一小球）

        diff = pos(b2,:) - pos(b1,:);
        dist = max(norm(diff), 1e-6);
        f = (dist - 2.0) * diff / dist;  % 目标距离为2
        force(b1,:) = force(b1,:) + f;
        force(b2,:) = force(b2,:) - f;
    end
    
    % 所有节点之间的斥力
    for a = 1:N_balls
        for b = a+1:N_balls
            diff = pos(b,:) - pos(a,:);
            dist = max(norm(diff), 1e-6);
            f = -3.0 / dist^2 * diff / dist;
            force(a,:) = force(a,:) + f;
            force(b,:) = force(b,:) - f;
        end
    end
    
    pos = pos + 0.01 * force;
end

%% 开始绘图
figure('Name', '连杆机构拓扑三维可视化', ...
       'Position', [100 100 900 700], ...
       'Color', 'white');
hold on; axis equal; grid on;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('连杆机构拓扑结构（三维）', 'FontSize', 14);
view(35, 25);

% 颜色定义
rod_colors = [0.2 0.6 1.0;   % 杆1：蓝
              1.0 0.4 0.2;   % 杆2：橙
              0.2 0.8 0.4;   % 杆3：绿
              0.8 0.2 0.8];  % 杆4：紫

%% 绘制杆（cylinder模拟）
for r = 1:N_rods
    b1 = rods.ball1(r);
    b2 = rods.ball2(r);
    % 处理各种端点情况：0 表示该端没有小球
    if b1 == 0 && b2 == 0
        % 两端都无小球：跳过绘制
        continue;
    elseif b1 == 0
        % 仅 b2 存在：从 b2 向外绘制半根杆
        p2 = pos(b2,:);
        p1 = p2 + (randn(1,3) / norm(randn(1,3)+1e-6)) * 1.0;
    elseif b2 == 0
        % 仅 b1 存在：从 b1 向外绘制半根杆
        p1 = pos(b1,:);
        p2 = p1 + (randn(1,3) / norm(randn(1,3)+1e-6)) * 1.0;
    else
        if b1 == b2
            % 悬空杆：两端在同一小球，向外延伸一小段
            p1 = pos(b1,:);
            p2 = p1 + randn(1,3) * 0.5;
        else
            p1 = pos(b1,:);
            p2 = pos(b2,:);
        end
    end
    
    % 绘制杆线
    plot3([p1(1) p2(1)], [p1(2) p2(2)], [p1(3) p2(3)], ...
          '-', 'LineWidth', 6, 'Color', rod_colors(r,:));
    
    % 标注杆编号
    mid = (p1 + p2) / 2;
    text(mid(1), mid(2), mid(3)+0.15, sprintf('杆%d', r), ...
         'FontSize', 11, 'FontWeight', 'bold', ...
         'Color', rod_colors(r,:), 'HorizontalAlignment', 'center');
end

%% 绘制小球节点
scatter3(pos(:,1), pos(:,2), pos(:,3), 300, ...
         'filled', 'MarkerFaceColor', [1 0.8 0], ...
         'MarkerEdgeColor', [0.5 0.3 0]);

% 标注小球编号
for b = 1:N_balls
    text(pos(b,1), pos(b,2), pos(b,3)+0.25, sprintf('球%d', b), ...
         'FontSize', 12, 'FontWeight', 'bold', ...
         'Color', [0.6 0.3 0], 'HorizontalAlignment', 'center');
end

%% 图例
legend_entries = arrayfun(@(r) sprintf('杆%d', r), 1:N_rods, ...
                          'UniformOutput', false);
% （根据需要添加图例）

hold off;
end