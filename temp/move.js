import React, { useState, useEffect } from "react";
import ReactDOM from "react-dom";

//This is a stupid react project made to mess around with the tools
// It lets you move around on the screen by clicking the O and using arrow keys
// It's not very fun
// Tries to make use of hooks
function test1() {
  const [count, setCount] = useState(0);
  const [yPos, setYPos] = useState(150);
  const [xPos, setXPos] = useState(150);
  const [r1, setR1] = useState(Math.ceil((Math.random() * 300) / 10) * 10);
  const [r2, setR2] = useState(Math.ceil((Math.random() * 300) / 10) * 10);
  
  useEffect(() => {
    // Update the document title using the browser API
    document.title = `Yeet`;
  });
  //doesn't work as intended
  
  
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
      <p>Your score: {count} </p>
      <div
        onKeyDown={keyPressed}
        
        tabIndex="0"
        style={{ position: "absolute", top: yPos, left: xPos }}
      >
        O
      </div>
    </div>
  );
}   
//alert('Click the O to start, use arrow keys to move!')
  const rootElement = document.getElementById("root");
ReactDOM.render(<test1 />, rootElement);
