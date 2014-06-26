function detected = reconstruct_detection(imgs, spots)

  [m,n,p] = size(imgs);

  detected = zeros(size(imgs));
  size_img = [m,n];

  if (~iscell(spots))
    spots = {spots};
  end

  zero = zeros(size_img);

  for i=1:p

    img = zero;
    curr_spots = spots{i};

    for s = 1:size(curr_spots, 1)

      gauss_params = curr_spots(s,:);

      img = img + GaussMask2D(gauss_params(3), size_img, gauss_params([2 1]), 0, 1)*gauss_params(4);
    end

    detected(:,:,i) = img;
  end

  detected = cast(detected, class(imgs));

  return;
end
