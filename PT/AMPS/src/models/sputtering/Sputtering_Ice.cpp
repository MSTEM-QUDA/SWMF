// source file for the physical model

#include "Sputtering.h"

double Sputtering::Ice::GetSputteringSpeed(int spec, double* v){
}

// description of Martin Rubin's model ----------------------------------------
inline double Sputtering::Ice::Rubin::SputteringYield(double speed,
						      int spec_projectile,
						      int spec_target){
  // Matrix contains sputtering yields for H2O
  // [Energy_level][Projectile]
  // Projectile = 0:H^+; 1:O^(n+), 2:O2^(n+)
  // Entry is calculated from E(eV) by int((log10(E)-1.47)/0.1)
  // Sputtering yield is linearly interpolated
  const static double YieldData[77][3]={
    {0.0000E+00, 0.0000E+00, 0.0000E+00},
    {1.2189E+00, 0.0000E+00, 0.0000E+00},
    {1.6346E+00, 0.0000E+00, 0.0000E+00},
    {2.0413E+00, 1.3084E+00, 0.0000E+00},
    {2.4445E+00, 1.7076E+00, 0.0000E+00},
    {2.9274E+00, 2.2285E+00, 0.0000E+00},
    {3.5057E+00, 2.9084E+00, 1.3049E+00},
    {4.1424E+00, 3.7957E+00, 1.7029E+00},
    {4.4843E+00, 4.5900E+00, 2.2224E+00},
    {4.8545E+00, 4.9956E+00, 2.9004E+00},
    {5.2552E+00, 5.4370E+00, 3.7853E+00},
    {5.5834E+00, 5.9174E+00, 4.6910E+00},
    {5.6050E+00, 6.1035E+00, 5.3956E+00},
    {5.6267E+00, 6.2297E+00, 6.2061E+00},
    {5.6486E+00, 6.3585E+00, 7.1383E+00},
    {5.6705E+00, 6.4899E+00, 7.7580E+00},
    {5.6924E+00, 6.8240E+00, 8.3513E+00},
    {5.7145E+00, 7.2673E+00, 8.9992E+00},
    {5.7367E+00, 7.7394E+00, 9.6974E+00},
    {5.7589E+00, 8.2421E+00, 1.0388E+01},
    {6.2521E+00, 8.8610E+00, 1.1014E+01},
    {6.8697E+00, 9.7362E+00, 1.1678E+01},
    {7.5482E+00, 1.0698E+01, 1.2255E+01},
    {8.4838E+00, 1.1755E+01, 1.2742E+01},
    {9.6829E+00, 1.2916E+01, 1.3331E+01},
    {1.1051E+01, 1.4191E+01, 1.4073E+01},
    {1.2626E+01, 1.5721E+01, 1.4857E+01},
    {1.4436E+01, 1.8377E+01, 1.8273E+01},
    {1.6507E+01, 2.1482E+01, 2.3093E+01},
    {1.8874E+01, 2.5111E+01, 2.9116E+01},
    {2.1581E+01, 3.1285E+01, 3.6559E+01},
    {2.4676E+01, 4.0769E+01, 4.5904E+01},
    {2.7509E+01, 4.7429E+01, 5.8892E+01},
    {3.0155E+01, 5.1168E+01, 7.5930E+01},
    {3.0883E+01, 5.5574E+01, 9.7896E+01},
    {2.9704E+01, 6.9086E+01, 1.2629E+02},
    {2.6026E+01, 8.5882E+01, 1.6294E+02},
    {2.1287E+01, 1.0676E+02, 2.1024E+02},
    {1.5623E+01, 1.3320E+02, 2.7022E+02},
    {1.1466E+01, 1.6724E+02, 3.4406E+02},
    {8.4154E+00, 2.0999E+02, 4.3807E+02},
    {6.3132E+00, 2.6936E+02, 5.6099E+02},
    {4.9850E+00, 3.4728E+02, 7.2768E+02},
    {3.9363E+00, 4.4775E+02, 9.4389E+02},
    {3.1082E+00, 5.4918E+02, 1.2243E+03},
    {2.4543E+00, 6.6287E+02, 1.5532E+03},
    {0.0000E+00, 8.0008E+02, 1.9659E+03},
    {0.0000E+00, 9.6570E+02, 2.4881E+03},
    {0.0000E+00, 1.0561E+03, 3.1346E+03},
    {0.0000E+00, 1.1225E+03, 3.8439E+03},
    {0.0000E+00, 1.0649E+03, 4.7136E+03},
    {0.0000E+00, 1.0102E+03, 5.7683E+03},
    {0.0000E+00, 9.0521E+02, 6.5421E+03},
    {0.0000E+00, 7.4138E+02, 7.4197E+03},
    {0.0000E+00, 6.0720E+02, 7.5824E+03},
    {0.0000E+00, 4.8969E+02, 7.5824E+03},
    {0.0000E+00, 3.8318E+02, 7.0401E+03},
    {0.0000E+00, 2.9983E+02, 6.3214E+03},
    {0.0000E+00, 2.3245E+02, 5.1415E+03},
    {0.0000E+00, 1.7994E+02, 4.1819E+03},
    {0.0000E+00, 1.3895E+02, 3.3329E+03},
    {0.0000E+00, 1.0712E+02, 2.6428E+03},
    {0.0000E+00, 8.2586E+01, 2.0899E+03},
    {0.0000E+00, 6.3903E+01, 1.6317E+03},
    {0.0000E+00, 4.9725E+01, 1.2740E+03},
    {0.0000E+00, 3.8693E+01, 9.9500E+02},
    {0.0000E+00, 3.0108E+01, 7.7766E+02},
    {0.0000E+00, 2.3363E+01, 6.0779E+02},
    {0.0000E+00, 1.8062E+01, 4.6551E+02},
    {0.0000E+00, 1.3963E+01, 3.5118E+02},
    {0.0000E+00, 1.0799E+01, 2.6510E+02},
    {0.0000E+00, 8.3838E+00, 2.0681E+02},
    {0.0000E+00, 6.5090E+00, 1.6133E+02},
    {0.0000E+00, 5.0624E+00, 0.0000E+00},
    {0.0000E+00, 3.9453E+00, 0.0000E+00},
    {0.0000E+00, 3.0748E+00, 0.0000E+00},
    {0.0000E+00, 0.0000E+00, 0.0000E+00},
  };

  if(spec_target != _H2O_SPEC_) 
    exit(__LINE__,__FILE__,"Error: uninitialized sputtering target species");
  // find projectile species' local id and mass
  int projectile;
  double m;
  switch(spec_projectile){
  case _H_PLUS_SPEC_:
    projectile = 0; m = _MASS_(_H_);  break;
  case _O_PLUS_THERMAL_SPEC_: case _O_PLUS_HIGH_SPEC_: case _O_PLUS_SPEC_:
    projectile = 1; m = _MASS_(_O_);  break;
  case _O2_PLUS_SPEC_:
    projectile = 2; m = _MASS_(_O2_); break;
  default:
    return 0.0;
  }
  double E = 0.5*m*speed*speed/ElectronCharge;  // Energy in eV
  int counter = int((log10(E)-1.47)/0.1);     // Derive array entry from energy
  if ((E > 1E9) || (YieldData[counter][projectile] < 1.0) || (counter < 0)) 
    return 0.0;
  double b = (log10(YieldData[counter+1][projectile]/YieldData[counter][projectile]))/0.1;
  double a = log10(YieldData[counter][projectile])-b*(1.47+counter*0.1);
  return pow(10,b*log10(E)+a);
}

// description of Benjamin Teolis's model -------------------------------------
inline double Sputtering::Ice::Teolis::SputteringYield(double speed,
						      int spec_projectile,
						      int spec_target){
  // Matrix contains sputtering yields for
  // [Energy_level][Target][Projectile]
  // Energy_level is calculated from energy E(eV) by 
  //         int((log10(E)-log10(Emin))/dLog10Energy)
  // Projectile = 0:H^+; 1:O^(n+), 2:O2^(n+)
  // Target     = 0:O2;  1:H2O
  // Sputtering yield is interpolated by log10(Y)=b*log10(E)+a
  // CAVEAT: yield for projectile O2 ion is taken equal to that of S ion
  const static int nEnergyLevel=100;
  const static double Emin =10, Emax = 6E6; // in eV
  const static double dLog10Energy =log10(Emax/Emin)/(nEnergyLevel-1);
  const static double YieldData[nEnergyLevel][2][3]=
    {
      { {0.00903, 0.00521, 0.00594}, {0.28629,   1.92738,   2.29507} },
      { {0.01125, 0.00573, 0.00650}, {0.30029,   2.07342,   2.48455} },
      { {0.01379, 0.00633, 0.00715}, {0.31449,   2.22864,   2.68787} },
      { {0.01670, 0.00702, 0.00788}, {0.32885,   2.39340,   2.90584} },
      { {0.02074, 0.00777, 0.00861}, {0.34332,   2.56805,   3.13928} },
      { {0.02538, 0.00861, 0.00945}, {0.35783,   2.75290,   3.38900} },
      { {0.03091, 0.00981, 0.01036}, {0.37234,   2.94826,   3.65586} },
      { {0.03727, 0.01122, 0.01139}, {0.38679,   3.15441,   3.94071} },
      { {0.04455, 0.01283, 0.01258}, {0.40110,   3.37159,   4.24440} },
      { {0.05278, 0.01824, 0.01807}, {0.41521,   3.60000,   4.56777} },
      { {0.06216, 0.02523, 0.02529}, {0.42904,   3.83981,   4.91165} },
      { {0.07198, 0.03629, 0.03640}, {0.44252,   4.09113,   5.27686} },
      { {0.08277, 0.05044, 0.05051}, {0.45558,   4.35403,   5.66418} },
      { {0.09511, 0.06664, 0.06665}, {0.46812,   4.62850,   6.07434} },
      { {0.10783, 0.08727, 0.08549}, {0.48007,   4.91450,   6.50805} },
      { {0.12164, 0.11200, 0.10723}, {0.49134,   5.21190,   6.96592} },
      { {0.13633, 0.14095, 0.13437}, {0.50184,   5.52050,   7.44852} },
      { {0.15205, 0.17471, 0.16759}, {0.51149,   5.84003,   7.95630} },
      { {0.16676, 0.21538, 0.20852}, {0.52021,   6.17016,   8.48965} },
      { {0.18304, 0.26225, 0.25582}, {0.52791,   6.51045,   9.04881} },
      { {0.20167, 0.31587, 0.30991}, {0.53453,   6.86043,   9.63391} },
      { {0.21845, 0.37515, 0.37242}, {0.53998,   7.21951,  10.24493} },
      { {0.23679, 0.44258, 0.44403}, {0.54422,   7.58707,  10.88171} },
      { {0.25427, 0.51695, 0.52556}, {0.54719,   7.96238,  11.54392} },
      { {0.27273, 0.60080, 0.61866}, {0.54887,   8.34469,  12.23103} },
      { {0.29385, 0.69671, 0.72515}, {0.54925,   8.73316,  12.94234} },
      { {0.31208, 0.80005, 0.84336}, {0.54835,   9.12694,  13.67694} },
      { {0.33012, 0.91523, 0.97687}, {0.54620,   9.52512,  14.43373} },
      { {0.34778, 1.03876, 1.12312}, {0.54289,   9.92680,  15.21137} },
      { {0.36540, 1.17292, 1.28477}, {0.53851,  10.33105,  16.00832} },
      { {0.38555, 1.32637, 1.46968}, {0.53321,  10.73696,  16.82281} },
      { {0.40482, 1.48796, 1.66913}, {0.52717,  11.14369,  17.65286} },
      { {0.42335, 1.65978, 1.88604}, {0.52061,  11.55044,  18.49626} },
      { {0.44227, 1.84528, 2.12705}, {0.51377,  11.95651,  19.35059} },
      { {0.46013, 2.03927, 2.39101}, {0.50695,  12.36134,  20.21324} },
      { {0.47957, 2.22505, 2.66180}, {0.50047,  12.76457,  21.08137} },
      { {0.50143, 2.42348, 2.95941}, {0.49469,  13.16605,  21.95200} },
      { {0.52643, 2.65045, 3.29983}, {0.49000,  13.56594,  22.82196} },
      { {0.55441, 2.85971, 3.64081}, {0.48682,  13.96480,  23.68793} },
      { {0.58615, 3.07772, 4.01031}, {0.48559,  14.36367,  24.54647} },
      { {0.61412, 3.27739, 4.37543}, {0.48680,  14.76417,  25.39405} },
      { {0.63953, 3.46653, 4.74764}, {0.49094,  15.16867,  26.22706} },
      { {0.66860, 3.68289, 5.17340}, {0.49856,  15.58048,  27.04188} },
      { {0.69936, 3.88629, 5.59867}, {0.51023,  16.00398,  27.83488} },
      { {0.73244, 4.08165, 6.03287}, {0.52655,  16.44492,  28.60255} },
      { {0.77079, 4.26357, 6.46536}, {0.54816,  16.91070,  29.34151} },
      { {0.81541, 4.40969, 6.86433}, {0.57576,  17.41065,  30.04863} },
      { {0.86646, 4.57683, 7.32068}, {0.61006,  17.95645,  30.72115} },
      { {0.92151, 4.72684, 7.77810}, {0.65185,  18.56253,  31.35680} },
      { {0.97916, 4.83250, 8.19791}, {0.70192,  19.24660,  31.95399} },
      { {1.04130, 4.93379, 8.62518}, {0.76111,  20.03021,  32.51203} },
      { {1.10084, 4.99004, 8.95264}, {0.83024,  20.93944,  33.03136} },
      { {1.16362, 5.05780, 9.27042}, {0.91013,  22.00566,  33.51390} },
      { {1.23163, 5.13775, 9.59335}, {1.00152,  23.26645,  33.96334} },
      { {1.30943, 5.22920, 9.96272}, {1.10502,  24.76675,  34.38562} },
      { {1.39174, 5.25992,10.26527}, {1.22100,  26.56014,  34.78937} },
      { {1.48078, 5.23841,10.51937}, {1.34949,  28.71050,  35.18646} },
      { {1.56761, 5.24252,10.70438}, {1.49005,  31.29397,  35.59264} },
      { {1.64664, 5.28600,10.77322}, {1.64156,  34.40144,  36.02818} },
      { {1.73704, 5.33574,10.85196}, {1.80202,  38.14153,  36.51869} },
      { {1.82818, 5.37334,10.94127}, {1.96840,  42.64442,  37.09601} },
      { {1.91468, 5.38840,11.04230}, {2.13637,  48.06645,  37.79920} },
      { {1.99744, 5.39895,11.14213}, {2.30029,  54.59594,  38.67581} },
      { {2.04848, 5.39302,11.21388}, {2.45318,  62.46034,  39.78328} },
      { {2.10687, 5.38624,11.29594}, {2.58694,  71.93502,  41.19074} },
      { {2.15801, 5.38497,11.38368}, {2.69290,  83.35418,  42.98118} },
      { {2.17058, 5.40258,11.46605}, {2.76251,  97.12414,  45.25423} },
      { {2.17999, 5.43416,11.53613}, {2.78841, 113.73963,  48.12960} },
      { {2.15410, 5.55498,11.43770}, {2.76545, 133.80350,  51.75146} },
      { {2.10937, 5.68323,11.30851}, {2.51852, 153.38953,  59.75338} },
      { {2.03967, 5.81774,11.14038}, {2.11440, 170.08760,  74.10624} },
      { {1.95995, 5.97159,10.94806}, {1.77513, 188.60344,  91.90669} },
      { {1.86675, 6.16407,10.80208}, {1.49029, 209.13492, 113.98284} },
      { {1.75750, 6.40588,10.73229}, {1.25116, 231.90146, 141.36172} },
      { {1.64344, 6.69485,10.71853}, {1.05040, 257.14639, 175.31705} },
      { {1.53916, 7.05512,10.86144}, {0.88185, 285.13949, 217.42852} },
      { {1.41989, 7.46721,11.02489}, {0.74035, 316.17994, 269.65523} },
      { {1.29873, 7.93181,11.24460}, {0.62155, 350.59947, 334.42688} },
      { {1.19992, 8.44561,11.58119}, {0.52182, 388.76593, 414.75680} },
      { {1.09469, 9.03170,11.97669}, {0.43809, 431.08721, 514.38211} },
      { {1.02142, 9.69230,12.49247}, {0.36779, 478.01562, 637.93759} },
      { {0.93761,10.44791,13.08245}, {0.30878, 530.05267, 791.17131} },
      { {0.84758,11.30501,13.77081}, {0.25923, 587.75451, 981.21203} },
      { {0.78518,12.23536,14.65214}, {0.21763, 651.73780,1216.90087} },
      { {0.71379,13.29953,15.66025}, {0.18271, 722.68635,1509.20258} },
      { {0.66312,14.50081,16.66017}, {0.15339, 801.35840,1871.71566} },
      { {0.61572,15.84281,17.77749}, {0.12985, 890.21005,2265.37002} },
      { {0.58369,17.30922,19.00128}, {0.11175, 985.75938,2608.92879} },
      { {0.54706,18.98655,20.40111}, {0.09618,1078.47654,3000.59849} },
      { {0.50734,20.83709,21.99509}, {0.08278,1162.93192,3444.97369} },
      { {0.46694,22.79576,23.80163}, {0.07124,1232.95413,3945.90893} },
      { {0.42388,24.92101,25.86031}, {0.06132,1282.45407,4505.75494} },
      { {0.39046,26.77011,28.17616}, {0.05278,1306.52928,5124.26566} },
      { {0.35224,28.88518,30.82511}, {0.04543,1302.54201,5797.13363} },
      { {0.31178,31.11327,33.84326}, {0.03911,1270.77136,6514.19217} },
      { {0.28411,32.56903,37.22788}, {0.03367,1214.36084,7257.48787} },
      { {0.25272,34.21086,41.08976}, {0.02899,1138.58035,7999.69194} },
      { {0.23278,34.65021,44.91627}, {0.02497,1049.70858,8703.63938} },
      { {0.20996,35.15275,49.29318}, {0.02150, 953.93818,9323.99830} },
      { {0.18387,35.72758,54.29967}, {0.01852, 856.59364,9811.88600} },
    };
  int projectile, target;
  double m;
  // determine target species local id
  for(target = 0; target < nSpecTarget; target++)
    if(spec_target == SpecTarget[target]) break;
  if(target == nSpecTarget)
    exit(__LINE__,__FILE__,"Error: uninitialized sputtering target species");

  // find projectile species' local id and mass
  switch(spec_projectile){
  case _H_PLUS_SPEC_:
    projectile = 0; m = _MASS_(_H_);  break;
  case _O_PLUS_THERMAL_SPEC_: case _O_PLUS_HIGH_SPEC_: case _O_PLUS_SPEC_:
    projectile = 1; m = _MASS_(_O_);  break;
  case _O2_PLUS_SPEC_:
    projectile = 2; m = _MASS_(_O2_); break;
  default:
    return 0.0;
  }
  double E = 0.5*m*speed*speed/ElectronCharge;      // Energy in eV
  if(E > Emax || E < Emin) return 0.0;
  int counter = int((log10(E/Emin))/dLog10Energy) - 1;// Derive array entry from energy
  // interpolate lenearly log10(Yield) = a + b * log10(E)
  double b = (log10(YieldData[counter+1][target][projectile]/YieldData[counter][target][projectile]))/dLog10Energy;
  double a = log10(YieldData[counter][target][projectile])-b*(log10(Emin)+counter*dLog10Energy);
  return pow(10,b*log10(E)+a);
}
