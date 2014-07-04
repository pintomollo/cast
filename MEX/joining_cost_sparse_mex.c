#include <math.h> /* Needed for the ceil() prototype */
#include "mex.h"

#define __MAX__(A, B)     ((A)>=(B)? (A) : (B))
#define __SQR__(A)        ((A) * (A))
#define __WGT__(A)        ((A)>=1? (A) : (1/((A)*(A))))

/// See paper "A Fast, Compact Approximation of the Exponential Function".
/// 2x to 9x faster than exp(x)!
/// Can be off by about +-4% in the range -100 to 100.
double fast_exp(double y) {
  double d;
  *((int*)(&d) + 0) = 0;
  *((int*)(&d) + 1) = (int)(1512775 * y + 1072632447);
  return d;
}

double get_signal(int frame_indx, int spot_indx, const mxArray *spots) {

  mwSize m, n;
  const mxArray *cell_element_ptr;
  double *spot;
  double signal;

  signal = 0;
  if (spot_indx >= 0) {
    cell_element_ptr = mxGetCell(spots, frame_indx);
    m  = mxGetM(cell_element_ptr);
    n  = mxGetN(cell_element_ptr);

    if (spot_indx < m && n > 3) {
      spot  = mxGetPr(cell_element_ptr);
      signal = __SQR__(spot[spot_indx + 2*m]) * spot[spot_indx + 3*m];
    }
  }

  return signal;
}

double get_next_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links) {

  mwSize mmax, m, n;
  mwIndex i,j, parent_indx, frame_indx;
  const mxArray *cell_element_ptr;
  double *curr_indx, *prev_indx, *frames;

  mmax = mxGetNumberOfElements(links);

  parent_indx = -1;
  for (j=frame+1; j<mmax; j++) {
    cell_element_ptr = mxGetCell(links, j);
    m  = mxGetM(cell_element_ptr);
    n  = mxGetN(cell_element_ptr);

    curr_indx  = mxGetPr(cell_element_ptr);
    prev_indx = curr_indx + m;
    frames = prev_indx + m;
    for (i=0; i<m; i++) {
      if (frames[i] == frame + 1 && prev_indx[i] == spot_indx + 1) {
        parent_indx = curr_indx[i] - 1;
        frame_indx = j;
        break;
      }
    }

    if (parent_indx != -1) {
      break;
    }
  }

  return get_signal(frame_indx, parent_indx, spots);
}

double get_prev_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links) {

  mwSize m, n;
  mwIndex i, child_indx, child_frame;
  const mxArray *cell_element_ptr;
  double *curr_indx, *prev_indx, *frame_indx;

  cell_element_ptr = mxGetCell(links, frame);
  m  = mxGetM(cell_element_ptr);
  n  = mxGetN(cell_element_ptr);

  curr_indx  = mxGetPr(cell_element_ptr);
  prev_indx = curr_indx + m;
  frame_indx = prev_indx + m;

  child_indx = -1;
  child_frame = 0;
  for (i=0; i<m; i++) {
    if (curr_indx[i] == spot_indx + 1) {
      child_indx = prev_indx[i] - 1;
      child_frame = frame_indx[i] - 1;
    }
  }

  return get_signal(child_frame, child_indx, spots);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  /* Declare variable */
  mwSize m1,n1, m2, n2;
  mwSize nzmax, nzstep;
  mwIndex *irs,*jcs,i,j, count, *irs2, *jcs2;
  const mxArray *spots, *links;
  double *x1,*y1,*t1,*x2,*y2,*t2,*rs,*i1,*i2, *rs2;
  double dist, dist2, thresh, thresh2, signal1, signal2, signal_prev;
  double weight, alt_weight, alt_move;
  bool is_test;

  /* Check for proper number of input and output arguments */
  if (nrhs == 4) {
    is_test = true;
  } else if (nrhs == 7) {
    is_test = false;
  } else {
    mexErrMsgIdAndTxt( "MATLAB:fulltosparse:invalidNumInputs",
        "Four or seven input arguments required.");
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
  i1  = x1 + (n1-2)*m1;
  t1  = x1 + (n1-1)*m1;

  m2  = mxGetM(prhs[1]);
  n2  = mxGetN(prhs[1]);

  x2  = mxGetPr(prhs[1]);
  y2  = x2 + m2;
  i2  = x2 + (n2-2)*m2;
  t2  = x2 + (n2-1)*m2;

  thresh = __SQR__(mxGetScalar(prhs[2]));
  thresh2 = mxGetScalar(prhs[3]);

  nzmax=(mwSize)ceil((double)m1*(double)m2*0.1);
  nzstep=(mwSize)__MAX__(ceil((double)nzmax*0.25),1);

  if (is_test) {
    plhs[0] = mxCreateDoubleMatrix(1,m2,mxREAL);
    rs  = mxGetPr(plhs[0]);

    for (i = 0; i < m2; i++) {
      for (j = 0; j < m1; j++) {
        dist2 = t2[i]-t1[j];

        dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j])) / __SQR__(dist2);

        if (dist < thresh && dist2 <= thresh2 && dist2 > 0) {
          rs[i] = true;
          break;
        }
      }
    }

  } else {

    alt_move = mxGetScalar(prhs[4]);
    alt_move = -__SQR__(alt_move);

    spots = prhs[5];
    links = prhs[6];

    plhs[0] = mxCreateSparse(m1,m2,nzmax,false);
    rs  = mxGetPr(plhs[0]);
    irs = mxGetIr(plhs[0]);
    jcs = mxGetJc(plhs[0]);

    plhs[1] = mxCreateDoubleMatrix(m2, 1,mxREAL);
    rs2  = mxGetPr(plhs[1]);

    count = 0;
    for (i = 0; i < m2; i++) {
      jcs[i] = count;

      signal2 = get_signal(t2[i]-1, i2[i]-1, spots);
      signal_prev = get_prev_signal(t2[i]-1, i2[i]-1, spots, links);

      alt_weight = __WGT__(signal2 / signal_prev);
      rs2[i] = -fast_exp(alt_move*alt_weight);

      for (j = 0; j < m1; j++) {
        dist2 = t2[i]-t1[j];

        dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j])) / __SQR__(dist2);

        if (dist < thresh && dist2 <= thresh2 && dist2 > 0) {

          if (count >= nzmax){
            nzmax += nzstep;

            mxSetNzmax(plhs[0], nzmax);
            mxSetPr(plhs[0], mxRealloc(rs, nzmax*sizeof(double)));
            mxSetIr(plhs[0], mxRealloc(irs, nzmax*sizeof(mwIndex)));

            rs  = mxGetPr(plhs[0]);
            irs = mxGetIr(plhs[0]);
          }

          signal1 = get_signal(t1[j]-1, i1[j]-1, spots);

          weight = __WGT__(signal2 / (signal1 + signal_prev));

          rs[count] = -fast_exp(-dist*weight);
          irs[count] = j;

          count++;
        }
      }
    }
    jcs[m2] = count;
  }
}
