import React, { useState, useEffect } from "react";
import ReactDOM from "react-dom";
import { createStore } from "redux";
import './styles.css'

//===================================
/*An awful game(?)
* should not be played(?) by anyone
*/
//===================================
//start of X O stuff (move.js)
//currently pretty , but I don't care to touch it up
function Example() {
  const [count, setCount] = useState(0);
  const [yPos, setYPos] = useState(150);
  const [xPos, setXPos] = useState(150);
  const [r1, setR1] = useState(Math.ceil((Math.random() * 250) / 10) * 10);
  const [r2, setR2] = useState(Math.ceil((Math.random() * 250) / 10) * 10);

  useEffect(() => {
    // Update the document title using the browser API
    document.title = `Yeet`;
  });

  function keyPressed(e) {
    //window.clearInterval(interval);
    var temp1 = yPos;
    var temp2 = xPos;
    var x = 0;
    var y = 0;

    if (e.key === "ArrowUp") {
      y = -10;
      x = 0;
    }

    if (e.key === "ArrowDown") {
      y = 10;
      x = 0;
    }
    if (e.key === "ArrowLeft") {
      y = 0;
      x = -10;
    }
    //window.clearInterval(interval);
    if (e.key === "ArrowRight") {
      y = 0;
      x = 10;
    }
    //doesnt know where it's supposed to be

    setXPos(temp2 + x);
    setYPos(temp1 + y);
    temp2 += x;
    temp1 += y;

    if (yPos === r1 && xPos === r2) {
      setR1(Math.ceil((Math.random() * 300) / 10) * 10);
      setR2(Math.ceil((Math.random() * 300) / 10) * 10);
      setCount(Math.floor(count + 50 * Math.random()));
    }
  }

  const s = {
    position: "absolute",
    top: r1,
    left: r2,
    height: "25px",
    width: "25px",
    color: "red",
    display: "inline-block"
  };
  return (
    <div>
      <span style={s}>X</span>
      <p id = 'top'>Your score: {count} </p>
      <div
        onKeyDown={keyPressed}
        tabIndex="0"
        style={{ position: "absolute", top: yPos, left: xPos }}
      >
        ʘ
      </div>
    </div>
  );
}
//alert('Click the O to start, use arrow keys to move!')
const rootElement = document.getElementById("root");
ReactDOM.render(<Example />, rootElement);

const initialState = {
  prev: [],
  color: "white",
  future: []
};

//=====================
//start of color stuff
//currently has a bug? feature? where if you undo, then change color then redo
//that color gets "inserted" between the two old colors
//I.e. If I do white, red, blue , then undo 2x then enter green
//then redo, it will proceed as if I put in white, green, red , blue
//Maybe it should delete the old future rather than inserting between it? 
function test(state = initialState, action) {
  var curr = state.color;
  var past = state.prev;
  var fut = state.future;
  switch (action.type) {
    case CHANGE_BG:
      return Object.assign({}, state, {
        prev: [curr, ...past].filter(function(element) {
          return element !== undefined;
        }),
        color: action.color,
        future: fut.filter(function(element) {
          return element !== undefined;
        })
      });

    case UNDO:
      if(past[0] === undefined)
      {
        return Object.assign({}, state, {
      
          color: curr ,
          prev: past ,
          future: fut
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
        })
      });}

    case REDO:
    if(fut[0] === undefined)
    {
      return Object.assign({}, state, {
    
        color: curr ,
        prev: past ,
        future: fut
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
        })
      });}
    default:
      return state;
  }
}

const CHANGE_BG = "CHANGE_BG";
const UNDO = "UNDO";
const REDO = "REDO";
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
  //if there is no past,don't undo?
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
//===================
//helpers

//helper function purloined from SO post
//incredibly dumb, but works fine
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

//changes to text color based on bg color
//partially adapted from so
//there is probably a better means of getting and parsing the rgb
function changeTextColor() {
  var rgb = window.getComputedStyle(document.body).backgroundColor;
  //if (red*0.299 + green*0.587 + blue*0.114) > 186 use #000000 else use #ffffff  
  //console.log(rgb.split("(")[1].split(",")[2].split(")"));
  var arr = rgb.split("(")[1].split(",");
  var val = (parseInt(arr[0],10)*0.299 + parseInt(arr[1],10)*0.587 + parseInt(arr[2].split(")")[0],10)*0.114);
  //console.log(val);
  if (val > 150){
    document.body.style.color = 'black' ;
  }
  else document.body.style.color = 'white';
  return;
}
//===================