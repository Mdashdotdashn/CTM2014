import de.voidplus.leapmotion.*;
import themidibus.*; //Import the library
import javax.sound.midi.MidiMessage; //Import the MidiMessage classes http://java.sun.com/j2se/1.5.0/docs/api/javax/sound/midi/MidiMessage.html
import javax.sound.midi.ShortMessage;

LeapMotion leap;
MidiBus myBus; // The MidiBus

int elapsedFrames = 0;
ArrayList points = new ArrayList();

int maxCenterCount = 9;
int centerCount = maxCenterCount;

float symmetries[];

int background = 255;
int foreground = 0;

float lastRotation = 0;
boolean isFullscreen = false;

int midiTick = 0;
PGraphics pg;

int colors[];
int colorCount;

int currentColorIndex = 0;
int paletteInterval = 10;
int selectedPalette = 1;

void resetPalette()
{
  paletteInterval = 10 + (int)random(40);

  switch(selectedPalette)
  {
  case 1:
    colorCount = 1;  
    colors = new int[colorCount];
    colors[0] = foreground;
    break;
    
  case 2:
    colorCount = 3;
    colors = new int[colorCount];
    colors[0] = color(79, 179, 194);
    colors[1] = color(252, 5, 5);
    colors[2] = color(237, 154, 135); 
    break;
    
  case 3:
    colorCount = 3;
    colors = new int[colorCount];
    colors[0] = color(243, 94, 55);
    colors[1] = color(209, 193, 141);
    colors[2] = color(80, 179, 184);
    break;

  case 4:
    colorCount = 3;
    colors = new int[colorCount];
    colors[0] = color(90, 48, 68);
    colors[1] = color(59, 134, 134);
    colors[2] = color(181, 181, 176);  
    break;
  }
  
  currentColorIndex = 0;
}

void resetCenters()
{
  centerCount = (int)random(maxCenterCount-2) + 2;
  float directionDelta = 2*PI/centerCount;

  for (int i=0; i< centerCount; i++)
  {
    symmetries[i] = directionDelta*i;
  } 
}

void resetAll()
{
  resetPalette();
  resetCenters();
}

void setup()
{
  if (isFullscreen)
  {
    size(displayWidth, displayHeight, JAVA2D);
  }
  else
  {
    size(1024, 768);
  }

  symmetries = new float[maxCenterCount];
  resetAll();
  
  pg = createGraphics(width, height, JAVA2D);
  
  background(background);
  pg.background(background);
  pg.stroke(0); pg.noFill();
  
  frameRate(60);
    
  leap = new LeapMotion(this);
  myBus = new MidiBus(this, "Port 1", "Port 1"); // Create a new MidiBus with no input device and the default Java Sound Synthesizer as the output device.
  
  smooth();
}

boolean sketchFullScreen()
{
  return isFullscreen;
}

boolean ccSwitch = true;
boolean handOnNow = false;

void doMidiStuff(ArrayList<Hand> hands)
{
  boolean handOnThisTime = (hands.size() != 0);
  
  // Send note on / off when hand appears / disappear
  
  if (handOnThisTime != handOnNow)
  {
    if (handOnThisTime)
    {
        myBus.sendNoteOn(0, 36, 127); // Send a Midi noteOn
    }
    else
    {
        myBus.sendNoteOff(0, 36, 127); // Send a Midi noteOn
    }
    handOnNow = handOnThisTime;
  }  
  else
  if (handOnNow)
  {
    Hand hand = hands.get(0);
    float hand_pitch = hand.getPitch();
    PVector hand_position    = hand.getPosition();
    float radius = 700-hand_position.y;
    if (radius < 400)
    {
      if (ccSwitch)
      {
        // Send hand heigth related controller      
        myBus.sendControllerChange(0, 100, (int)(radius*127./400.)); // Send a controllerChange
      }
      else
      {
        int pitch_control = (int)abs(hand_pitch);
        if (pitch_control<0) hand_pitch = 0;
        if (pitch_control>60) hand_pitch = 60;
        pitch_control = 60 - pitch_control;
      
        myBus.sendControllerChange(0, 50, pitch_control*2); // Send a controllerChange
      }
      ccSwitch = !ccSwitch;
    }
  }
}

void createPoint(PVector position,float lifetime)
{
  PVector vel = new PVector(0, 0);
  Point punt = new Point(position, vel, lifetime, colors[currentColorIndex / 50]);
  currentColorIndex = (currentColorIndex+1) % (colorCount*50);
  points.add(punt);
}

void updateBackBuffer(ArrayList<Hand> hands)
{
  // HANDS

  pg.beginDraw();
  pg.translate(width/2, height/2);  

   
  if(hands.size() !=0 )
  {
    Hand hand = hands.get(0);
    
    PVector hand_position    = hand.getPosition();
    float   hand_pitch       = hand.getPitch();

    lastRotation = hand_pitch*PI/60;
    
    float radius = 700-hand_position.y;
 
    if (radius < 400)
    {
      PVector pos = new PVector(radius, 0);
      pos.rotate(lastRotation);
      
      float lifetime = 200 + abs(radius)/2.0;

      createPoint(pos, lifetime);
    }   
  }
  
  for(int i = 0; i < points.size(); i++)
  {
   Point localPoint = (Point) points.get(i);
   if(localPoint.isDead == true  || leap.getHands().size() ==0)
   {
    points.remove(i);
   }
   else
   {
     localPoint.update();
     for (int j = 0; j < centerCount; j++)
     {
       localPoint.draw(symmetries[j]);
     }
   }
  }
  pg.endDraw();
}

boolean invert = false;
float lastRadarAngle = 200;
boolean sentPing = false;

int pingTicks = 1000;
PVector pingPosition = new PVector();

void updateRadar(ArrayList<Hand> hands)
{
  if(hands.size() !=0 )
  {
    Hand hand = hands.get(0);
    
    PVector hand_position    = hand.getPosition();
    float   hand_pitch       = hand.getPitch();

    lastRotation = hand_pitch*PI/60;
    
    float radius = 700-hand_position.y;
    
    float clockRotation = 2*PI*midiTick/96.0;

    PVector radar = new PVector(400,0);
    radar.rotate(clockRotation);
    
    PVector radar2 = new PVector(radius,0);
    radar2.rotate(lastRotation);
    
    float angle = PVector.angleBetween(radar, radar2);
    
    if (angle != lastRadarAngle && angle < 0.15 && pingTicks > 50)
    {
      if (angle> lastRadarAngle)
      {
        if (!sentPing)
        {
         myBus.sendNoteOn(1, 48, 127); // Send a Midi noteOn
         pingPosition = radar2;
         pingPosition.mult(0.5);
         pingTicks = 0;
         sentPing = true;
        }
      }
      else
      {
        if (sentPing)
        {
         myBus.sendNoteOff(1, 48, 127); // Send a Midi noteOn
         sentPing = false;
        }      
      }
    
      lastRadarAngle = angle;
    }
//    line(0,0,radar2.x, radar2.y);
//    line(0,0,radar.x, radar.y);

  }  
  else
  {
    lastRadarAngle = 200;
  }
}

void drawPing()
{
  int transparency = 255 - pingTicks * 10;
  if (transparency > 0)
  {
    stroke(foreground, transparency);
    fill(foreground, transparency);
    int size = 10;
    int weight = 2;
    
    rect(pingPosition.x - size, pingPosition.y - weight, size *2, weight*2);
    rect(pingPosition.x - weight , pingPosition.y - size, weight*2, size *2);
    
  }
  if (pingTicks < 60)
  {
    createPoint(pingPosition.get(), 25);    
  }
  pingTicks++;
}

void draw()
{

  ArrayList<Hand> hands = leap.getHands();
  doMidiStuff(hands);
  
  updateBackBuffer(hands);

  
  background(background);
  image(pg, 0, 0);
  translate(width/2, height/2);
  stroke(foreground);

  updateRadar(hands);
  drawPing();
  
  if (invert)
  {
    filter(INVERT);
  }
  elapsedFrames++;    
}

void leapOnInit(){
  // println("Leap Motion Init");
}
void leapOnConnect(){
  // println("Leap Motion Connect");
}
void leapOnFrame(){
  // println("Leap Motion Frame");
}
void leapOnDisconnect(){
  // println("Leap Motion Disconnect");
}
void leapOnExit(){
  // println("Leap Motion Exit");
}

class Point
{   
  PVector pos, vel, noiseVec;
  float noiseFloat, lifeTime, age;
  boolean isDead;
  color fillColor;
   
  public Point(PVector _pos, PVector _vel, float _lifeTime, color _fillColor)
  {
    pos = _pos;
    vel = _vel;
    lifeTime = _lifeTime;
    age = 0;
    isDead = false;
    fillColor = _fillColor;
    noiseVec = new PVector();
  }
   
  void update(){
    noiseFloat = noise(pos.x * 0.0025, pos.y * 0.0025, elapsedFrames * 0.001);
    noiseVec.x = cos(((noiseFloat - 0.3) * TWO_PI) * 20);
    noiseVec.y = sin(((noiseFloat - 0.3) * TWO_PI) * 20);
     
    vel.add(noiseVec);
    vel.div(2);
    pos.add(vel);
     
    if(age > lifeTime)
    {
     isDead = true;
    }
     
    if(pos.x < 0 || pos.x > width || pos.y < 0 || pos.y > height){
//     isDead = true;
    }
     
    age++;   
  }
   
  void draw(float rotation)
  {   
    pg.fill(fillColor,30);
    pg.noStroke();
    PVector p = pos.get();
    p.rotate(rotation);
    pg.ellipse(p.x, p.y, 1-(age/lifeTime), 1-(age/lifeTime));
  }
};

void keyPressed(){
  if(key == ' '){
    for(int i = 0; i < points.size(); i++){
       Point localPoint = (Point) points.get(i);
       localPoint.isDead = true;
    }
    pg.noStroke();
    background = 255 - background;
    foreground = 255 - foreground ;
    resetAll();
    pg.fill(background);
    pg.rect(-width/2, -height/2, width, height);
  }
  
  if (key == '&')
  {
    selectedPalette = 1;
  }
  if (key == 'é')
  {
    selectedPalette = 2;
  }
  if (key == '\"')
  {
    selectedPalette = 3;
  }
  if (key == '\'')
  {
    selectedPalette = 4;
  }
}

void noteOn(int channel, int pitch, int velocity) 
{
  if (channel == 1){
    invert = true; 
  };
}

void noteOff(int channel, int pitch, int velocity)
{
  if (channel == 1){
    invert = false; 
  };
}

void controllerChange(int channel, int number, int value)
{
}

void midiMessage(MidiMessage message) 
{
 if (message.getStatus() == ShortMessage.TIMING_CLOCK)
  {
    midiTick = (midiTick +1)%96;
  }
}
