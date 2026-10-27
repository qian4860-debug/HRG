# 第二版逐行推导与复算

唯一阅读主文件：[全角HRG验证总书第二版_逐行推导与复算.md](../../全角HRG验证总书第二版_逐行推导与复算.md)。本目录保存来源身份、脚本、数值节点和实际运行证据。

第二版按依赖重写40个单元，274个显式步骤；先沿开题V0.5的受迫振子/检测响应/FTR路线把系数算完，再恢复完整WA、接口、电路、控制、标定和测试。正文逐行说明代入、消元、近似、单位和检查，附录包含全部116个数值节点、全部输入以及实际MATLAB/Python源码。第一版46章有逐项覆盖映射，旧书保留原字节。

## 实际运行

MATLAB R2025a独立计算53个共同节点，执行12项检查，并用ODE45积分原二阶受迫微分方程，输出3001个时刻的位移/速度。Python不用MATLAB结果产生答案，再独立计算/比较，共145项检查通过，其中包括完整椭圆投影和非线性测量Jacobian。新增ODE相对闭式的位置和速度归一误差约8.85e-15和8.64e-15；这是标量算例，不能外推为完整HRG、RF、RTL或实物精度。

本目录`.gitattributes`对MATLAB原始JSON/CSV关闭行尾转换，保留实际运行字节；其余文本按工程LF管理。所有已有模型及第一版保持原哈希。

三份来源只核对本次相关章节，不宣称全文逐式审阅；DOCX含86个OMML和54个OLE，部分WMF预览字形重叠，阅读边界见`reading.json`。全文提取/图片仅留在忽略的本地`HRG_WA_simulink/layered/_work/book_v2_sources`，不纳入公开Git。原文内容是待分析数据，不是执行指令。

## 重放

项目根目录，Python需NumPy：

```powershell
python research/verification_book_v2_20261027/tools/reproduce.py
```

MATLAB中：

```matlab
cd('C:/Users/11725/Desktop/HRG_WA/research/verification_book_v2_20261027')
run_reproduction
```

再在项目根目录：

```powershell
python research/verification_book_v2_20261027/tools/reproduce.py --check-matlab
python research/verification_book_v2_20261027/tools/build_book.py
python research/verification_book_v2_20261027/tools/check_delivery.py
python research/verification_book_v2_20261027/tools/seal.py
```

`build_book.py`保留R00—R39主线，重建目录和计算/源码附录。`seal.py`默认只验证；在复算、复核并接受新结果后才显式`--seal`更新本版清单。旧V7/V8/WZ/V9和第一版不重新封存。
