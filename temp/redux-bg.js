import { createStore } from 'redux'

// This is a stupid redux project made to test the tools
// It does not use react-redux, it does the UI with plain old js
// Typing a color in the text box and hitting enter will change the screen color
// Undo and redo can go through your "color history"
const initialState = {
  prev : [],
  color : 'white' ,
  future : []
}

function test(state = initialState, action) {
  var curr = state.color;
  var past = state.prev;
  var fut = state.future;
  
  switch(action.type){
    case CHANGE_BG : 
      return Object.assign({}, state, {
        prev : [curr, ...past] ,
        color: action.color,
        future : fut
      })
    case UNDO :  
    return Object.assign({},state,{
      color : past[0],
      prev : past.slice(1),
      future : [curr, ...fut]
    })
    case REDO :
    return Object.assign({},state,{
      color : fut[0],
      prev : [curr, ...past],
      future : fut.slice(1)
    })
    default:
      return state
  }
}

const CHANGE_BG = 'CHANGE_BG'
const UNDO = 'UNDO'
const REDO = 'REDO'
const store = createStore(test)


function changeBg(color){
  return {
    type: CHANGE_BG,
    color
  }
}
const boundChangeBg = color => store.dispatch(changeBg(color))

function undo(){
  return {
    type: UNDO
  }
}
const boundUndo = color => store.dispatch(undo())

function redo(){
  return {
    type: REDO
  }
}
const boundRedo = color => store.dispatch(redo())


var a = document.createElement('input');
 document.getElementById('root').appendChild(a);
 a.placeholder = "Enter a color";
 a.onkeydown = (e) =>{
   if(e.key === 'Enter'){
      boundChangeBg(a.value);
      a.value = '';
      document.body.style.backgroundColor = '' + store.getState().color; 
     }
 };

 var b = document.createElement('button');
 document.getElementById('root1').appendChild(b);
 b.innerHTML = 'undo'
 b.onclick = () => {
    boundUndo();
    
    document.body.style.backgroundColor = '' + store.getState().color;      
 }

 var c = document.createElement('button');
 document.getElementById('root1').appendChild(c);
 c.innerHTML = 'redo'
 c.onclick = () => {
    boundRedo();
    document.body.style.backgroundColor = '' + store.getState().color;      
 }

