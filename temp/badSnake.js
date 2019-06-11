import React, { useState, useEffect } from "react";
import ReactDOM from "react-dom";
import { createStore } from "redux";
import './styles.css'

//===================================
/*An awful game(?)
* May be the worst thing I've ever made
* Known issues:
* Sometime you slip into the void while moving
* Sometimes X spawns in out of view places 
*/

//===================================
//start of X O stuff (move.js)
//currently pretty , but I don't care to touch it up
//uses react api

var s;
var speed = (window.innerHeight/20);
//console.log(speed);
function Example() {
  //set up hooks
  const [count, setCount] = useState(0);
  const [highScore,setHighScore] = useState(document.cookie.split("highscore=")[1]);
  const [yPos, setYPos] = useState(150);
  const [xPos, setXPos] = useState(150);
  const [timer, setTimer] = useState(0);
  const [r1, setR1] = useState((Math.random() * window.innerHeight));
  const [r2, setR2] = useState((Math.random() * window.innerWidth));


  useEffect(() => {
    // Update the document title using the browser API
    document.title = `Yeet`;
  });

  function keyPressed(e) {
    
    //simply moves updates some style controlling variables on keypresses
    var temp1 = yPos;
    var temp2 = xPos;
    var x = 0;
    var y = 0;
    if (e.key === "ArrowUp") {
      y = -1 * speed;
      x = 0;
    }
    if (e.key === "ArrowDown") {
      y = 1 * speed;
      x = 0;
    }
    if (e.key === "ArrowLeft") {
      y = 0;
      x = -1 * speed;
    }
    //window.clearInterval(interval);
    if (e.key === "ArrowRight") {
      y = 0;
      x = 1 * speed;
    } 
    setXPos(temp2 + x);
    setYPos(temp1 + y);
    temp2 += x;
    temp1 += y;
    //must be exactly over the x as of now, maybe should make it a range
    if (isNear(yPos,r1) && isNear(xPos,r2)) {
      setR1((Math.random() * window.innerHeight));
      setR2((Math.random() * window.innerWidth));
      setCount(Math.floor(count + 75 * Math.random()));
  }
  if(highScore < count){
    document.cookie = "highscore = " + count;
   // console.log(document.cookie.split("highscore=")[1]);
    setHighScore(count);
  }
}
  function click(e){
     var p = document.getElementById('kill');
     p.parentNode.removeChild(p);
     var curr = 100;
     setTimer(100);
     var i = setInterval(function(){
        setTimer(curr--);
        if(curr <= 0){      
          clearInterval(i);
          var plr = document.getElementById('player');
          plr.parentNode.removeChild(plr); 
        }
      }, 50);
     
    }
//apparently styling can be done like this
  s = {
    position: "absolute",
    top: r1,
    left: r2,
    height: "25px",
    width: "25px",
    display: "inline-block",
    color : 'red'
  };
  function mClick(e){
    document.getElementById("nerd").textContent = "Only nerds don't like marquees"
    console.log("Cry me a river, nerd"); 
  }
  //Displays everything, score updates randomly btw
  return (
    <div>
      <span id='x' style={s}>X</span>
      <marquee onClick = {mClick} style = {{fontFamily: 'monospace', margin: '-5px'}}><p id = 'nerd'>Refresh Page to Replay</p></marquee>
      <p id = 'top'>Time:{timer} Your score:{count} High Score:{highScore} </p>
      <div
        onKeyDown={keyPressed}
        tabIndex="0"
        id = 'player'
        style={{ position: "absolute", top: yPos, left: xPos }}
        onClick = {click}>
        ʘ
        <p id = 'kill' style = {{margin : '-3px'}}>{"↑↑ click me....use arrow keys"}</p>
      </div>
    </div>
  );
}

const rootElement = document.getElementById("root");
ReactDOM.render(<Example />, rootElement);

//=====================
//start of color stuff
//Uses redux api 

const initialState = {
  prev: [],
  color: "white",
  future: [],
  isCycling : false
};

function test(state = initialState, action) {
  var curr = state.color;
  var past = state.prev;
  var fut = state.future;
  
  switch (action.type) {
    case CHANGE_BG:
      return Object.assign({}, state, {
        //Had to try to filter everything to fix an old bug... 
        prev: [curr, ...past].filter(function(element) {
          return element !== undefined;
        }),
        color: action.color,
        future: fut.filter(function(element) {
          return element !== undefined;
        }),
        isCycling : false
      });

    case UNDO:
      if(past[0] === undefined)
      {
        return Object.assign({}, state, {
      
          color: curr ,
          prev: past ,
          future: fut,
          isCycling : false
        });
      }
      else{
      return Object.assign({}, state, {
      
        color: past[0] ,
        prev: past.slice(1).filter(function(element) {
          return element !== undefined;
        }),
        future: [curr, ...fut].filter(function(element) {
          return element !== undefined;
        }),
        isCycling : false
      });}

    case REDO:
    if(fut[0] === undefined)
    {
      return Object.assign({}, state, {
    
        color: curr ,
        prev: past ,
        future: fut,
        isCycling : false
      });
    }
    else{
      return Object.assign({}, state, {
        color: fut[0],
        prev: [curr, ...past].filter(function(element) {
          return element !== undefined;
        }),
        future: fut.slice(1).filter(function(element) {
          return element !== undefined;
        }),
        isCycling : false
      });} 
    case CYCLE:
    if(!state.isCycling){
        return Object.assign({},state,{
          color: curr ,
          prev: past ,
          future: fut ,
          isCycling : true
        });    }
      else {return Object.assign({},state,{
        color: curr ,
        prev: past ,
        future: fut ,
        isCycling : false
      });
    }

    default:
      return state;
  }
}

const CHANGE_BG = "CHANGE_BG";
const UNDO = "UNDO";
const REDO = "REDO";
const CYCLE = "CYCLE";
const store = createStore(test);

function changeBg(color) {
  return {
    type: CHANGE_BG,
    color
  };
}
const boundChangeBg = color => store.dispatch(changeBg(color));

function undo() {
  return {
    type: UNDO
  };
}
const boundUndo = color => store.dispatch(undo());

function redo() {
  return {
    type: REDO
  };
}
const boundRedo = color => store.dispatch(redo());

function cycle() {
  return {
    type: CYCLE
  };
}
const boundCycle = color => store.dispatch(cycle());
//Uses regular js to make some elements to interact
//with the redux stuff and change the bgColors
//I don't like react-redux

var a = document.createElement("input");
document.getElementById("root1").appendChild(a);
a.placeholder = "Enter a color";
a.onkeydown = e => {
  if (e.key === "Enter" && GoodColor(a.value)) {
    boundChangeBg(a.value);
    a.value = "";
    document.body.style.backgroundColor = "" + store.getState().color;
    changeTextColor();
  } else if (e.key === "Enter") a.value = "";
};

var b = document.createElement("button");
document.getElementById("root1").appendChild(b);
b.innerHTML = "undo";
b.onclick = () => {
  boundUndo();
  document.body.style.backgroundColor = "" + store.getState().color;
  changeTextColor(); 
};

var c = document.createElement("button");
document.getElementById("root1").appendChild(c);
c.innerHTML = "redo";
c.onclick = () => {
  
  //if(store.getState().color !== undefined)
  boundRedo();
  document.body.style.backgroundColor = "" + store.getState().color;
  changeTextColor();
};
//is supposed to continually go through the
//color array saved in store
//var si;
var d = document.createElement("button");
document.getElementById('root1').appendChild(d);
d.innerHTML = "cycle";
d.onclick = () => {
 boundCycle();
 console.log(store.getState());
 alert("NYI");
 
 /*
  si = setInterval(()=>{
    if(store.getState().prev.length > 0 && store.getState().isCycling){
        
      boundUndo();
      document.body.style.backgroundColor = "" + store.getState().color;
      changeTextColor(); 
    }
  else {
      boundRedo();
      document.body.style.backgroundColor = "" + store.getState().color;
      changeTextColor(); 
    }
  },200);

  if(!store.getState().isCycling) clearInterval(si);
*/
};

//===================
//helper functions!

//helper function purloined from SO post
//incredibly dumb, but works fine
//meant to determine if text is a color
function GoodColor(color) {
  var color2 = "";
  var result = true;
  var e = document.getElementById("root1");
  e.style.borderColor = "";
  e.style.borderColor = color;
  color2 = e.style.borderColor;
  if (color2.length === 0) {
    result = false;
  }
  e.style.borderColor = "";
  return result;
}

//changes text color based on bg color
//partially adapted from so
//there is probably a better means of getting and parsing the rgb
function changeTextColor() {
  var rgb = window.getComputedStyle(document.body).backgroundColor;
  //console.log(rgb.split("(")[1].split(",")[2].split(")"));
  var arr = rgb.split("(")[1].split(",");
  var val = (parseInt(arr[0],10)*0.299 + parseInt(arr[1],10)*0.587 + parseInt(arr[2].split(")")[0],10)*0.114);
  //console.log(val);
  if (val > 150){
    document.body.style.color = 'black' ;
  }
  else document.body.style.color = 'white';
  var x =document.getElementById('x');
  if(parseInt(arr[0],10) > 175){
     x.style.color = 'green';    
  }
  else x.style.color = 'red';
  return;
}

function isNear(a,b){
  let val = Math.abs(a-b);
  if(val <= speed + 5) return true;
  else return false;
}

//===================
