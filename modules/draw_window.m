function img = draw_window(params, size_img)

  img = zeros(size_img);

  xindx = round(params(1) + [-params(3):params(3)]);
  yindx = round(params(2) + [-params(4):params(4)]);

  xindx = xindx(xindx > 0 & xindx <= size_img(2));
  yindx = yindx(yindx > 0 & yindx <= size_img(1));

  img(yindx, xindx) = params(5);

  return;
end
