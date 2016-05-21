
void drawSlider(Animation animation, int x, int w) {
  int y = colorPickerY-15;
  int h = 10;
  stroke(0x99, 0x99, 0x99);
  line(x, y+(h/2), x+w, y+(h/2)+1);
  
  if (mousePressed && mouseX >= x && mouseX < x+w && mouseY >= y && mouseY < y+h) {
    float fx = float(x);
    float fmx = float(mouseX);
    float fw = float(w);
    animation.speedPct = int((fmx-fx) / fw * 100);
    println("new rate for "+animation.name+": "+animation.speedPct);
  }
  int sliderPos = int((float(animation.speedPct) / 100.0) * float(w));   
  strokeWeight(10);
  stroke(255);
  point(x+sliderPos, y+(h/2));
  strokeWeight(1);
}