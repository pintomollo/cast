#include <string.h> 
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  /* Declare variable */
  mwSize m, n;
  mwIndex *irs,*jcs,i,count,curr_col;
  double *indx1,*indx2,*value, *rs;

  /* Check for proper number of input and output arguments */
  if (nrhs != 1) {
    mexErrMsgIdAndTxt( "MATLAB:fulltosparse:invalidNumInputs",
        "One input argument required.");
  }

  /* Check data type of input argument  */
  if (!(mxIsSparse(prhs[0]))) {
    mexErrMsgIdAndTxt( "MATLAB:fulltosparse:inputNotSparse",
        "Input arguments must be of type sparse.");
  }

  /* Get the size and pointers to input data */
  m  = mxGetM(prhs[0]);
  n  = mxGetN(prhs[0]);

  rs  = mxGetPr(prhs[0]);
  irs = mxGetIr(prhs[0]);
  jcs = mxGetJc(prhs[0]);

  count = jcs[n];

  plhs[0] = mxCreateDoubleMatrix(count, 1, mxREAL);
  plhs[1] = mxCreateDoubleMatrix(count, 1, mxREAL);
  plhs[2] = mxCreateDoubleMatrix(count, 1, mxREAL);

  indx1  = mxGetPr(plhs[0]);
  indx2  = mxGetPr(plhs[1]);
  value  = mxGetPr(plhs[2]);

  memcpy(value, rs, count*sizeof(double));

  curr_col = 0;
  for (i = 0; i < count; i++) {
    while (jcs[curr_col] <= i) {
      curr_col++;
    }
    indx1[i] = irs[i] + 1;
    indx2[i] = curr_col;
  }
}
