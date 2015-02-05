#include <math.h> // Needed for the ceil() prototype
#include "gaussian_spots.h"

/// Approximation of the exponential function from :
/// N. N. Schraudolph. A Fast, Compact Approximation of the Exponential Function. 
/// Neural Computation, 11(4):853–862, 1999.

/// 2x to 9x faster than exp(x)!
/// Can be off by about +-4% in the range -100 to 100.
double fast_exp(double y) {
  double d;
  y = (y < -700) ? -700 : (y > 700 ? 700 : y);
  *((int*)(&d) + 0) = 0;
  *((int*)(&d) + 1) = (int)(1512775 * y + 1072632447);
  return d;
}

// Compute the actual signal
double compute_signal(double *spots, int spot_indx, int nrows) {

  return M_2PI * __SQR__(spots[spot_indx + 2*nrows]) * spots[spot_indx + 3*nrows];
}

// Retrieve the signal from a gaussian spot in a cell array of spot matrices
double get_signal(int frame_indx, int spot_indx, const mxArray *spots) {

  mwSize m, n;
  const mxArray *cell_element_ptr;
  double *spot;
  double signal;

  signal = 0;
  if (spot_indx >= 0) {

    // Get the corresponding cell content
    cell_element_ptr = mxGetCell(spots, frame_indx);
    m  = mxGetM(cell_element_ptr);
    n  = mxGetN(cell_element_ptr);

    // Compute the signal as the integral under the 2D gaussian
    if (spot_indx < m && n > 3) {
      spot  = mxGetPr(cell_element_ptr);
      signal = compute_signal(spot, spot_indx, m);
    }
  }

  return signal;
}

// Retrives the signal of the spot next in the track of the current spot
double get_next_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links) {

  mwSize mmax, m, n;
  mwIndex i,j, parent_indx, frame_indx;
  const mxArray *cell_element_ptr;
  double *curr_indx, *prev_indx, *frames;

  mmax = mxGetNumberOfElements(links);

  // Look for a link that points towards us, in all consecutive frames
  parent_indx = -1;
  for (j=frame+1; j<mmax; j++) {
    cell_element_ptr = mxGetCell(links, j);
    m  = mxGetM(cell_element_ptr);
    n  = mxGetN(cell_element_ptr);

    curr_indx  = mxGetPr(cell_element_ptr);
    prev_indx = curr_indx + m;
    frames = prev_indx + m;

    // Need to check each individual link
    for (i=0; i<m; i++) {
      if (frames[i] == frame + 1 && prev_indx[i] == spot_indx + 1) {
        parent_indx = curr_indx[i] - 1;
        frame_indx = j;
        break;
      }
    }

    // When found, stop
    if (parent_indx != -1) {
      break;
    }
  }

  // Retrives the corresponding signal
  return get_signal(frame_indx, parent_indx, spots);
}

// Get the signal of the previous spot in the track of the current spot
double get_prev_signal(int frame, int spot_indx, const mxArray *spots, const mxArray *links) {

  mwSize m, n;
  mwIndex i, child_indx, child_frame;
  const mxArray *cell_element_ptr;
  double *curr_indx, *prev_indx, *frame_indx;

  cell_element_ptr = mxGetCell(links, frame);
  m  = mxGetM(cell_element_ptr);
  n  = mxGetN(cell_element_ptr);

  // Here it's easier as we know that our spot must point towards its predecessor
  curr_indx  = mxGetPr(cell_element_ptr);
  prev_indx = curr_indx + m;
  frame_indx = prev_indx + m;

  // So simply find the link of the current spot
  child_indx = -1;
  child_frame = 0;
  for (i=0; i<m; i++) {
    if (curr_indx[i] == spot_indx + 1) {
      child_indx = prev_indx[i] - 1;
      child_frame = frame_indx[i] - 1;

      break;
    }
  }

  // Retrieve the signal of the corresponding spot
  return get_signal(child_frame, child_indx, spots);
}
