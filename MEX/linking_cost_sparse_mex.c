#include <math.h> /* Needed for the ceil() prototype */
#include "mex.h"

#define __MAX__(A, B)     ((A)>=(B)? (A) : (B))
#define __SQR__(A)        ((A) * (A))

/// See paper "A Fast, Compact Approximation of the Exponential Function".
/// 2x to 9x faster than exp(x)!
/// Can be off by about +-4% in the range -100 to 100.
double fast_exp(double y) {
  double d;
  *((int*)(&d) + 0) = 0;
  *((int*)(&d) + 1) = (int)(1512775 * y + 1072632447);
  return d;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  /* Declare variable */
  mwSize m1,n1, m2, n2;
  mwSize nzmax, nzstep;
  mwIndex *irs,*jcs,i,j, count;
  double *x1,*y1,*x2,*y2,*rs;
  double dist, thresh;

  /* Check for proper number of input and output arguments */
  if (nrhs != 3) {
    mexErrMsgIdAndTxt( "MATLAB:fulltosparse:invalidNumInputs",
        "Three input arguments required.");
  }

  /* Check data type of input argument  */
  if (!(mxIsDouble(prhs[0]) && mxIsDouble(prhs[1]) && mxIsDouble(prhs[2]))){
    mexErrMsgIdAndTxt( "MATLAB:fulltosparse:inputNotDouble",
        "Input arguments must be of type double.");
  }

  /* Get the size and pointers to input data */
  m1  = mxGetM(prhs[0]);
  n1  = mxGetN(prhs[0]);

  x1  = mxGetPr(prhs[0]);
  y1  = x1 + m1;

  m2  = mxGetM(prhs[1]);
  n2  = mxGetN(prhs[1]);

  x2  = mxGetPr(prhs[1]);
  y2  = x2 + m2;

  thresh = __SQR__(mxGetScalar(prhs[2]));

  nzmax=(mwSize)ceil((double)m1*(double)m2*0.1);
  nzstep=(mwSize)__MAX__(ceil((double)nzmax*0.25),1);

  plhs[0] = mxCreateSparse(m1,m2,nzmax,false);
  rs  = mxGetPr(plhs[0]);
  irs = mxGetIr(plhs[0]);
  jcs = mxGetJc(plhs[0]);

  count = 0;
  for (i = 0; i < m2; i++) {
    jcs[i] = count;
    for (j = 0; j < m1; j++) {
      dist = __SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j]);

      if (dist <= thresh) {

        if (count >= nzmax){
          nzmax += nzstep;

          mxSetNzmax(plhs[0], nzmax);
          mxSetPr(plhs[0], mxRealloc(rs, nzmax*sizeof(double)));
          mxSetIr(plhs[0], mxRealloc(irs, nzmax*sizeof(mwIndex)));

          rs  = mxGetPr(plhs[0]);
          irs = mxGetIr(plhs[0]);
        }

        rs[count] = -fast_exp(-dist);
        irs[count] = j;

        count++;
      }
    }
  }
  jcs[m2] = count;
}
