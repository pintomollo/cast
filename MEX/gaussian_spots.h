#ifndef SPOTS_H
#define SPOTS_H

#include "mex.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#ifndef M_2PI
#define M_2PI 6.28318530717958647692
#endif

// Define few opeartions useful to compute the costs
#ifndef __MAX__
#define __MAX__(A, B)     ((A)>=(B)? (A) : (B))
#endif
#ifndef __SQR__
#define __SQR__(A)        ((A) * (A))
#endif
#ifndef __WGT__
#define __WGT__(A)        ((A)>=1? (A) : (1/((A)*(A))))
#endif

#ifdef __cplusplus
extern "C" {
#endif

double fast_exp(double y);
double compute_signal(double *spots, int spot_indx, int nrows);
double get_signal(int frame_indx, int spot_indx, const mxArray *spots);
double get_next_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links);
double get_prev_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links);

#ifdef __cplusplus
}
#endif

#endif
