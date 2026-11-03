"""A0 公共格式与纯数学工具；这里不含仿真真参数。"""
from pathlib import Path
import hashlib
import json
import numpy as np


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write_json(path, value):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)+'\n').encode('utf-8'))


def write_csv(path, values, columns):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8', newline='\n') as stream:
        np.savetxt(stream, values, delimiter=',', header=','.join(columns), comments='', fmt='%.17g')


def read_record(path):
    with Path(path).open('r', encoding='utf-8') as stream:
        assert stream.readline().strip() == 't,u_x,u_y,y_x,y_y', '观测文件只能有t/u/y列'
        values = np.loadtxt(stream, delimiter=',')
    assert values.ndim == 2 and values.shape[1] == 5 and np.all(np.isfinite(values))
    return values


def phasors(record, bins):
    return 2*np.fft.fft(record[:, 1:5], axis=0)[bins]/len(record)


def regress(records, bins, fs, method, instrument_model=None):
    """由记录的DFT建立二阶实系数矩阵回归；IV工具仅用已知外部输入。"""
    x_all, z_all, rhs_all = [], [], []
    for record in records:
        p = phasors(record, bins); u, y = p[:, :2], p[:, 2:]
        w = 2*np.pi*np.asarray(bins)*fs/len(record)
        x = np.c_[1j*w[:, None]*y, y, -u]
        # 输入独立于测量噪声；不读取真实输出/参数来构造工具变量。
        if instrument_model is None:
            z = np.c_[1j*w[:, None]*u, u, -(w*w)[:, None]*u]
        else:
            predicted = np.array([np.linalg.solve(-wi*wi*np.eye(2)+1j*wi*instrument_model['D']+instrument_model['K'],
                                                 instrument_model['B']@ui) for wi, ui in zip(w, u)])
            z = np.c_[1j*w[:, None]*predicted, predicted, -u]
        rhs = (w*w)[:, None]*y
        x_all.extend([x.real, x.imag]); z_all.extend([z.real, z.imag]); rhs_all.extend([rhs.real, rhs.imag])
    x, z, rhs = np.vstack(x_all), np.vstack(z_all), np.vstack(rhs_all)
    xs = np.maximum(np.linalg.norm(x, axis=0), 1e-30); zs = np.maximum(np.linalg.norm(z, axis=0), 1e-30)
    xn, zn = x/xs, z/zs
    lhs, target = (xn, rhs) if method == 'OLS' else (zn.T@xn, zn.T@rhs)
    coef, _, rank, singular = np.linalg.lstsq(lhs, target, rcond=1e-12)
    assert rank == 6, '输入/数据不足以辨识该二阶对象'
    coef = coef/xs[:, None]
    return dict(D=coef[:2].T, K=coef[2:4].T, B=coef[4:6].T,
                condition=float(singular[0]/singular[-1]),
                residual=float(np.linalg.norm(x@coef-rhs)/max(np.linalg.norm(rhs), 1e-30)))


def pack(model):
    return np.r_[model['D'].ravel(), model['K'].ravel(), model['B'].ravel()]


def unpack(vector):
    return dict(D=np.asarray(vector[:4]).reshape(2, 2), K=np.asarray(vector[4:8]).reshape(2, 2),
                B=np.asarray(vector[8:12]).reshape(2, 2))


def constraints(model, omega_ref):
    rows = []
    for op in [model['D']/omega_ref, model['K']/omega_ref**2]:
        rows.append([op[0, 1], (op[1, 1]-op[0, 0])/np.sqrt(2), -op[1, 0]])
    return np.array(rows)


def solve_metric(matrix):
    _, singular, vh = np.linalg.svd(matrix, full_matrices=True)
    z = vh[-1]
    w = np.array([[z[0], z[1]/np.sqrt(2)], [z[1]/np.sqrt(2), z[2]]])
    trace = np.trace(w)
    if abs(trace) < 1e-12:
        return None, singular
    w *= 2/trace
    if np.min(np.linalg.eigvalsh(w)) <= .05:
        return None, singular
    return w, singular


def angle_increment(y, metric=None):
    z = y if metric is None else y@np.linalg.cholesky(metric)
    phase = np.unwrap(np.arctan2(z[:, 1], z[:, 0]))
    return phase-phase[0]
