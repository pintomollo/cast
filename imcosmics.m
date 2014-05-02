function [new_img] = imcosmics(img, block_size, thresh)

  if (nargin == 1)
    block_size = 10;
    thresh = 30;
  elseif (nargin == 2)
    thresh = 30;
  end

  nplanes = size(img, 3);
  if (nplanes > 1)
    new_img = img;
    for i=1:nplanes
      new_img(:,:,i) = imcosmics(img(:,:,i), block_size, thresh);
    end

    return;
  end

  for i=1:5
    new_img = blockproc(img, [block_size block_size], @filter_cosmics, 'BorderSize', ceil([block_size block_size]/2));
    if (all(new_img(:) == img(:)))
      break;
    end
    img = new_img;
  end

  return;

  function res = filter_cosmics(block_struct)

    res = block_struct.data;
    data = res(:);
    data(data == 0) = NaN;

    dmed = nanmedian(data);
    dmad = 1.4826 * nanmedian(abs(data-dmed));

    [data, indx] = sort(data);
    dist = [0; diff(data)];

    bads = (data > dmed & dist > thresh*dmad);
    if (any(bads))
      first = find(bads, 1, 'first');
      res(indx(first:end)) = dmed;
    end

    return;
  end
end
