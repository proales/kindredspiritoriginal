// TODO: color picker should only show actual colors supported
// TODO: should show a box around the color that's currently selected?
public class ColorPicker {
  int x, y, w, h;
  PImage cpImage;
  public ColorPicker(int x, int y, int w, int h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    cpImage = new PImage(w, h);
    init();
  }
  private void init () {
    int cw = w - 30;
    for (int i = 0; i < cw; i++) {
      float nColorPercent = i / (float)cw;
      float rad = (-360 * nColorPercent) * (PI / 180);
      int nR = (int)(cos(rad) * 127 + 128) << 16;
      int nG = (int)(cos(rad + 2 * PI / 3) * 127 + 128) << 8;
      int nB = (int)(Math.cos(rad + 4 * PI / 3) * 127 + 128);
      int nColor = nR | nG | nB;
      setGradient(i, 0, 1, h/2, 0xFFFFFF, nColor);
      setGradient(i, (h/2), 1, h/2, nColor, 0x000000);
    }
    //drawRect(cw, 0,   30, h/2, 0xFFFFFF);
    //drawRect(cw, h/2, 30, h/2, 0);
    for (int j = 0; j < h; j++) {
      int g = 255 - (int)(j/(float)(h-1) * 255 );
      drawRect(w-30, j, 30, 1, color( g, g, g ));
    }
  }
  private void setGradient(int x, int y, float w, float h, int c1, int c2 ) {
    float deltaR = red(c2) - red(c1);
    float deltaG = green(c2) - green(c1);
    float deltaB = blue(c2) - blue(c1);
    for (int j = y; j < (y+h); j++) {
      int c = color(red(c1)+(j-y)*(deltaR/h),
                    green(c1)+(j-y)*(deltaG/h),
                    blue(c1)+(j-y)*(deltaB/h));
      cpImage.set(x, j, c);
    }
  }
  private void drawRect(int rx, int ry, int rw, int rh, int rc) {
    for(int i = rx; i < rx+rw; i++) {
      for(int j = ry; j < ry+rh; j++) {
        cpImage.set(i, j, rc);
      }
    }
  }
  public void draw() {
    image(cpImage, x, y);
  }
  public Integer getColorOverMouse() {
    if (mouseX >= x && mouseX < x + w && mouseY >= y && mouseY < y+h) {
      return new Integer(get(mouseX, mouseY));
    } else {
      //  mouse isn't over this color picker
      return null;
    }
  }
}