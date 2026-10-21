"""Check physical distinctions and analytically known limiting cases."""
import math
import unittest
import bandwidth_budget as b


class BudgetTests(unittest.TestCase):
    def test_actual_adc_rejects_behavioral_sampling_rate(self):
        with self.assertRaises(ValueError):
            b.ad9215_check(40000)
        b.ad9215_check(5e6)

    def test_dac_hold_known_half_nyquist_point(self):
        h = b.zoh(250000,1000000)
        self.assertAlmostEqual(abs(h),math.sin(math.pi/4)/(math.pi/4))
        self.assertAlmostEqual(math.degrees(math.atan2(h.imag,h.real)),-45)

    def test_cic_dc_and_first_zero(self):
        self.assertAlmostEqual(abs(b.cic(0,40000,40,3)),1)
        self.assertLess(abs(b.cic(1000,40000,40,3)),1e-12)

    def test_analog_onepole_corner(self):
        self.assertAlmostEqual(b.db(b.lowpass(100,100)),-3.01029995664,places=8)

    def test_opposite_pair_same_n2_not_differential(self):
        a=b.modal_matrix(False); g=b.modal_matrix(True)
        for row in range(2):
            for k in range(4):
                self.assertAlmostEqual(a[row][k],a[row][k+4])
                self.assertAlmostEqual(g[row][k],2*a[row][k])
        # Orthogonal grouped columns span both mechanical modal coordinates.
        self.assertAlmostEqual(g[0][0]*g[1][1]-g[0][1]*g[1][0],4)

    def test_motion_units(self):
        # A 360 deg/s body rotation gives .277 wave revolutions per second.
        # cos(2 theta) therefore cycles .554 times/s, cos(4 theta) 1.108 times/s.
        x=b.motion_terms(360,.277)
        self.assertAlmostEqual(x['iq_orientation_hz'],.554)
        self.assertAlmostEqual(x['rs_orientation_hz'],1.108)

    def test_pll_complementary_noise_paths(self):
        for f in [0,1,10,100000]:
            self.assertAlmostEqual(abs(b.pll_reference(f,5,.707)+b.pll_vco(f,5,.707)-1),0)
        self.assertAlmostEqual(abs(b.pll_reference(0,5,.707)),1)
        self.assertLess(abs(b.pll_reference(100000,5,.707)),.001)

    def test_jitter_uses_analog_tone_not_clock(self):
        self.assertAlmostEqual(b.jitter_limit(5000,80)/b.jitter_limit(1e6,80),200)


if __name__=='__main__':
    unittest.main()
