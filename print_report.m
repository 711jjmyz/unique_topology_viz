function print_report(balls, rods, is_unique)

fprintf('\n========== 拓扑重构报告 ==========\n');
fprintf('小球（铰接点）数量：%d\n', balls.count);
fprintf('杆件数量：%d\n', rods.count);
fprintf('\n--- 每根杆的连接情况 ---\n');
for r = 1:rods.count
    b1 = rods.ball1(r);
    b2 = rods.ball2(r);
    if b1 == b2
        fprintf('杆%d：两端连接同一个球（球%d）→ 悬空杆\n', r, b1);
    else
        fprintf('杆%d：端点1 → 球%d，端点2 → 球%d\n', r, b1, b2);
    end
end

fprintf('\n--- 每个小球连接的杆 ---\n');
for b = 1:balls.count
    connected_rods = [];
    for r = 1:rods.count
        if rods.ball1(r) == b || rods.ball2(r) == b
            connected_rods = [connected_rods, r];
        end
    end
    fprintf('球%d：连接了杆 %s\n', b, num2str(connected_rods));
end

fprintf('\n--- 唯一性验证 ---\n');
if is_unique
    fprintf('该连接矩阵A具有拓扑唯一性！\n');
else
    fprintf('警告：该连接矩阵A存在多种拓扑解！\n');
end
fprintf('===================================\n');
end