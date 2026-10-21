"""Expose original local helpers verbatim; preserve and hash original source."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT.parents[1]/'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA_v46_simulate.m'
s=SOURCE.read_text(encoding='utf-8')
functions=s[s.index('function log = local_allocate_log'):]
init=s[s.index('x.energy ='):s.index('log = local_allocate_log(count, t);')]
dispatch='''function varargout=wl_legacy(action,varargin)
% Generated dispatcher: local helper bodies below are verbatim V4.6.5 source.
switch action
 case 'init'
  p=varargin{1};
'''+init+'''
  varargout={st};
 case 'kalman'
  [varargout{1:nargout}]=local_kalman_step(varargin{:});
 case 'pi'
  [varargout{1:nargout}]=local_pi_aw(varargin{:});
 case 'rls'
  [varargout{1:nargout}]=local_rls_vector_update(varargin{:});
 case 'parameter_kf'
  [varargout{1:nargout}]=local_kf_parameter_update(varargin{:});
 case 'online'
  [varargout{1:nargout}]=local_online_calibration_step(varargin{:});
 case 'frp'
  [varargout{1:nargout}]=local_frp_joint_identification(varargin{:});
 case 'schedule'
  [varargout{1:nargout}]=local_frp_schedule(varargin{:});
 otherwise,error('Unknown algorithm adapter action');
end
end
'''+functions
dest=ROOT/'legacy';dest.mkdir(parents=True,exist_ok=True)
(dest/'wl_legacy.m').write_bytes(dispatch.encode('utf-8'))
record=dict(source=str(SOURCE),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 helper_bodies_sha256=hashlib.sha256(functions.encode()).hexdigest(),
 note='Local helpers copied verbatim; dispatcher and measurement/state adapters are new. No original file modified.')
(dest/'provenance.json').write_bytes(json.dumps(record,ensure_ascii=False,indent=2).encode())
print('Exported original helpers and state initializer without changing source.')
