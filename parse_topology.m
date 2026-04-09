function [balls, rods] = parse_topology(x_sol, A, a)
% 解析拓扑：基于 ILP 解 x_sol 和邻接矩阵 A，识别小球（nodes）与杆（rods）关系
% 说明：
% - 输入变量索引与 build_constraints 中的定义一致。
% - a5 用于指示每根杆端点是否应存在小球（参见用户说明）。

N = size(A,1);
if nargin < 3
    a = zeros(N,1);
end

% 索引函数: v(i,k,j,n)
idx = @(i,k,j,n) (i-1)*(4*N) + (k-1)*(2*N) + (j-1)*2 + n;

% 先收集每个端点实际的连接信息（基于 x_sol）
endpoint_conn = cell(N,2);
conn_count = zeros(N,2); % 每个端点与其他端点的直接连接数
for i = 1:N
    for k = 1:2
        endpoint_conn{i,k} = [];
        for j = 1:N
            if j == i, continue; end
            for n = 1:2
                if x_sol(idx(i,k,j,n)) == 1
                    endpoint_conn{i,k} = [endpoint_conn{i,k}; j, n];
                    conn_count(i,k) = conn_count(i,k) + 1;
                end
            end
        end
    end
end

% 决定哪些端点应当被视为有小球（include_endpoint = true）
include_endpoint = false(N,2);
for i = 1:N
    total_conn = sum(conn_count(i,:));
    for k = 1:2
        if conn_count(i,k) > 0
            include_endpoint(i,k) = true; % 实际连到其它端点，必然参与小球组
        elseif a(i) == 1
            include_endpoint(i,k) = true; % a5=1 表示两端都有小球
        else
            include_endpoint(i,k) = false; % a5=0 且未检测到直接连接：不包含小球
        end
    end
end

% 为被包含的端点建立并查集，合并那些通过 x_sol 连接的端点，得到小球聚类
% 我们只对 include_endpoint == true 的端点进行聚类
ep_index = zeros(N,2); % 为被包含的端点分配连续 id
cur = 0;
for i = 1:N
    for k = 1:2
        if include_endpoint(i,k)
            cur = cur + 1;
            ep_index(i,k) = cur;
        end
    end
end

parent = 1:cur;
function r = find_root(p, x)
    while p(x) ~= x
        x = p(x);
    end
    r = x;
end

% Union 操作：遍历所有被包含的端点上的连接
for i = 1:N
    for k = 1:2
        if ~include_endpoint(i,k), continue; end
        conns = endpoint_conn{i,k};
        for c = 1:size(conns,1)
            j = conns(c,1); n = conns(c,2);
            if ~include_endpoint(j,n)
                % 如果目标端点原本被标记为不包含（按 a5 规则），但 x_sol 表示有连接，
                % 那么强制包含它（以保证连通性一致性）并分配 id
                cur = cur + 1;
                ep_index(j,n) = cur;
                include_endpoint(j,n) = true;
                parent(cur) = cur;
            end
            id1 = ep_index(i,k);
            id2 = ep_index(j,n);
            if id1 > 0 && id2 > 0
                r1 = find_root(parent, id1);
                r2 = find_root(parent, id2);
                if r1 ~= r2
                    parent(r1) = r2;
                end
            end
        end
    end
end

% 生成小球映射：每个并查集根对应一个球
ball_map = containers.Map('KeyType','int32','ValueType','int32');
ball_count = 0;
ep_root = zeros(cur,1);
for id = 1:cur
    ep_root(id) = find_root(parent, id);
    r = ep_root(id);
    if ~isKey(ball_map, int32(r))
        ball_count = ball_count + 1;
        ball_map(int32(r)) = ball_count;
    end
end

% balls 结构体
balls = struct();
balls.count = ball_count;
balls.ep_to_ball = zeros(N,2); % 若端点没有小球则为0
for i = 1:N
    for k = 1:2
        id = ep_index(i,k);
        if id == 0
            balls.ep_to_ball(i,k) = 0;
        else
            root = ep_root(id);
            balls.ep_to_ball(i,k) = ball_map(int32(root));
        end
    end
end

% rods 结构体：每根杆对应两个端点的小球编号（0 表示无小球）
rods = struct();
rods.count = N;
rods.ball1 = balls.ep_to_ball(:,1);
rods.ball2 = balls.ep_to_ball(:,2);

fprintf('识别到 %d 个小球节点，%d 根杆（部分端点可能无小球，标记为0）。\n', ball_count, N);
end