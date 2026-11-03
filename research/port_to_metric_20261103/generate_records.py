"""独立A0合成记录生成器。真参数只写入private_score，估计器不导入本文件。"""
from pathlib import Path
import argparse
import numpy as np
from a0_common import write_csv, write_json, sha

HERE = Path(__file__).resolve().parent


def axis(a):
    return np.array([[np.cos(2*a), np.sin(2*a)], [np.sin(2*a), -np.cos(2*a)]])


def frequency_record(d, k, g, h, bins, rng, sigma, channel, n=1024, fs=32.):
    t = np.arange(n)/fs
    u, r = np.zeros((n, 2)), np.zeros((n, 2))
    for b in bins:
        omega = 2*np.pi*b*fs/n
        amplitude = (.12+.02*rng.random())*np.exp(1j*rng.uniform(-np.pi, np.pi))
        drive = np.zeros(2, dtype=complex); drive[channel] = amplitude
        response = np.linalg.solve(-omega**2*np.eye(2)+1j*omega*d+k, g@drive)
        wave = np.exp(1j*omega*t)
        u += np.real(wave[:, None]*drive)
        r += np.real(wave[:, None]*response)
    # 周期稳态初值，解析生成；不使用估计器的回归过程产生数据。
    y = r@h.T+sigma*rng.normal(size=r.shape)
    return np.c_[t, u, y]


def motion_record(d, k, g, h, rng, sigma):
    t = np.arange(1601)*.03
    chi = .25+.15*t+.12*np.sin(.27*t)
    speed = .15+.12*.27*np.cos(.27*t); acceleration = -.12*.27**2*np.sin(.27*t)
    amplitude = .9+.08*np.sin(.19*t+.3)
    adot = .08*.19*np.cos(.19*t+.3); addot = -.08*.19**2*np.sin(.19*t+.3)
    e = np.c_[np.cos(chi), np.sin(chi)]; tangent = np.c_[-np.sin(chi), np.cos(chi)]
    r = amplitude[:, None]*e
    velocity = adot[:, None]*e+(amplitude*speed)[:, None]*tangent
    accel = (addot-amplitude*speed**2)[:, None]*e+(2*adot*speed+amplitude*acceleration)[:, None]*tangent
    u = np.linalg.solve(g, (accel+velocity@d.T+r@k.T).T).T
    y = r@h.T+sigma*rng.normal(size=r.shape)
    return np.c_[t, u, y], np.c_[t, chi, r]


def generate(root):
    root = Path(root)
    specifications = [('A_clean', 1., False, 0., 100)]
    specifications += [('A_noisy', 1., False, 1e-4, s) for s in range(200, 205)]
    specifications += [('B_coaxial', 1., True, 0., 300), ('C_isotropic', 0., False, 0., 400)]
    specifications += [('D_weak_noisy', .001, False, .005, s) for s in range(500, 505)]
    specifications += [('A_noisy', 1., False, 1e-4, s) for s in range(210, 215)]
    specifications += [('D_weak_noisy', .001, False, .005, s) for s in range(510, 515)]
    protocol = dict(schema='A0-records-v1', synthetic=True, normalized_model=True,
                    sample_rate=32., samples=1024, train_bins=[4, 6, 8, 9, 10, 11, 12, 14, 18, 24],
                    holdout_bins=[5, 7, 13, 17, 23], repeats=6, reference_omega=2.,
                    uncertainty_inflation=6., numeric_constraint_floor=1e-9,
                    null_direction_budget_rad=.02, known_handedness=1,
                    uncertainty_scope='重复观测估计的经验误差裕量，不是严格有限样本置信证明', cases=[])
    truth = dict(schema='A0-private-score-v1', cases=[])
    for idx, (kind, scale, coaxial, sigma, seed) in enumerate(specifications, 1):
        cid = f'case_{idx:03d}'; structural = np.random.default_rng(seed)
        h = np.array([[1.2, .15], [-.08, .85]])+.025*structural.normal(size=(2, 2))
        g = np.array([[.9, -.04], [.03, 1.1]])+.02*structural.normal(size=(2, 2))
        assert np.linalg.det(h) > 0
        d = .4*np.eye(2)+scale*.04*axis(.11)
        k = 4*np.eye(2)+scale*.2*axis(.11 if coaxial else .69)
        public = dict(id=cid, train=[], holdout_transfer=[])
        for rep in range(protocol['repeats']):
            pair = []
            for channel in range(2):
                name = f'{cid}/train_{rep:02d}_{channel}.csv'
                data = frequency_record(d, k, g, h, protocol['train_bins'], np.random.default_rng(seed*100+rep*2+channel), sigma, channel)
                write_csv(root/'observations'/name, data, ['t', 'u_x', 'u_y', 'y_x', 'y_y']); pair.append(name)
            public['train'].append(pair)
        for channel in range(2):
            name = f'{cid}/holdout_transfer_{channel}.csv'
            data = frequency_record(d, k, g, h, protocol['holdout_bins'], np.random.default_rng(seed*100+900+channel), sigma, channel)
            write_csv(root/'observations'/name, data, ['t', 'u_x', 'u_y', 'y_x', 'y_y']); public['holdout_transfer'].append(name)
        motion, reference = motion_record(d, k, g, h, np.random.default_rng(seed*100+950), sigma)
        name = f'{cid}/holdout_motion.csv'; public['holdout_motion'] = name
        write_csv(root/'observations'/name, motion, ['t', 'u_x', 'u_y', 'y_x', 'y_y'])
        write_csv(root/'private_score'/f'{cid}_motion_truth.csv', reference, ['t', 'chi', 'r_x', 'r_y'])
        protocol['cases'].append(public)
        truth['cases'].append(dict(id=cid, kind=kind, seed=seed, noise_sigma=sigma,
            cohort='independent' if idx > 13 else 'development',
            D=d.tolist(), K=k.tolist(), H=h.tolist(), G=g.tolist(),
            expected_eligible=kind.startswith('A'), reference=f'{cid}_motion_truth.csv'))
    write_json(root/'observations'/'protocol.json', protocol)
    write_json(root/'private_score'/'truth.json', truth)
    write_json(root/'generation_manifest.json', dict(observation_sha256={p.relative_to(root/'observations').as_posix():sha(p) for p in sorted((root/'observations').rglob('*')) if p.is_file()},
        generator_sha256=sha(Path(__file__)), limits=['归一化二阶条件模型','周期稳态训练，未覆盖任意启动瞬态','未接完整12状态压电电路']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--root', type=Path, default=HERE/'data')
    generate(parser.parse_args().root)
    print('Generated independent observation and private scoring records.')
