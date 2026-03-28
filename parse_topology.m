function [balls, rods] = parse_topology(x_sol, A)
% 从64个变量的解中，识别小球节点和杆件信息

N = 4;
idx = @(i,k,j,n) (i-1)*16 + (k-1)*8 + (j-1)*2 + n;

%% 建立端点连接表
% endpoint_conn(i,k) = {(j,n), ...} 表示杆i端k连接了哪些端点
endpoint_conn = cell(N, 2);
for i = 1:N
    for k = 1:2
        endpoint_conn{i,k} = [];
        for j = 1:N
            if j == i, continue; end
            for n = 1:2
                if x_sol(idx(i,k,j,n)) == 1
                    endpoint_conn{i,k} = [endpoint_conn{i,k}; j, n];
                end
            end
        end
    end
end

%% 聚类识别小球
% 每个端点 (i,k) 是一个节点，共8个端点
% 如果两个端点相连，则合并到同一个小球

parent = 1:(2*N);  % 端点编号: (i-1)*2+k
ep_id = @(i,k) (i-1)*2 + k;

function r = find_root(parent, x)
    while parent(x) ~= x
        x = parent(x);
    end
    r = x;
end

% Union操作
for i = 1:N
    for k = 1:2
        conns = endpoint_conn{i,k};
        for c = 1:size(conns, 1)
            j = conns(c, 1);
            n = conns(c, 2);
            % 合并端点 (i,k) 和 (j,n)
            ri = find_root(parent, ep_id(i,k));
            rj = find_root(parent, ep_id(j,n));
            if ri ~= rj
                parent(ri) = rj;
            end 
        end
    end
end

%% 生成小球列表
ball_map = containers.Map('KeyType','int32','ValueType','int32');
ball_count = 0;
for ep = 1:8
    root = find_root(parent, ep);
    if ~isKey(ball_map, int32(root))
        ball_count = ball_count + 1;
        ball_map(int32(root)) = ball_count;
    end
end

% balls结构体
balls = struct();
balls.count = ball_count;
balls.ep_to_ball = zeros(N, 2);  % 端点归属的小球编号
for i = 1:N
    for k = 1:2
        root = find_root(parent, ep_id(i,k));
        balls.ep_to_ball(i,k) = ball_map(int32(root));
    end
end

% rods结构体
rods = struct();
rods.count = N;
rods.ball1 = balls.ep_to_ball(:,1);  % 每根杆端点1对应的小球
rods.ball2 = balls.ep_to_ball(:,2);  % 每根杆端点2对应的小球

fprintf('识别到 %d 个小球节点，%d 根杆\n', ball_count, N);
end