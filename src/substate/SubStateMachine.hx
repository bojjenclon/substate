/****
*
*   substate
*   =================================
*   A Single Hierarchical State Machine
*
*              |_
*        _____|~ |______ ,.
*       ( --  subSTATE  `+|
*     ~~~~~~~~~~~~~~~~~~~~~~~
*
* Copyright 2014 Infinite Descent. All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification, are
* permitted provided that the following conditions are met:
*
*    1. Redistributions of source code must retain the above copyright notice, this list of
*       conditions and the following disclaimer.
*
*    2. Redistributions in binary form must reproduce the above copyright notice, this list
*       of conditions and the following disclaimer in the documentation and/or other materials
*       provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY INFINITE DESCENT ``AS IS'' AND ANY EXPRESS OR IMPLIED
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
* FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL INFINITE DESCENT OR
* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
* CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
* ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* The views and conclusions contained in the software and documentation are those of the
* authors and should not be interpreted as representing official policies, either expressed
* or implied, of Infinite Descent.
*
****/

package substate;

import substate.core.ObserverTransitionCollection;
import haxe.ds.StringMap;

class SubStateMachine implements ISubStateMachine {
	//----------------------------------
	//  CONSTS
	//----------------------------------
    public static inline var UNINITIALIZED_STATE:String = "uninitializedState";

    // NOOPs
    private static var UNKNOWN_STATE:IState = new NoopState("unknown.state");
    private static var UNKNOWN_PARENT_STATE:IState = new NoopState("unknown.parent.state");
    private static var NO_PARENT_STATE:IState = new NoopState("no.parent.state");

    // Expected IState Constants
    public static inline var WILDCARD:String = "*";
    public static inline var NO_PARENT:String = null;

    //----------------------------------
	//  vars
	//----------------------------------
	/* @private */
	private var _nameToStates:StringMap<IState>;

    /* @private */
    private var _notificationCache:Array<Array<String>>;

	/* @private */
	private var _observerCollection:ObserverTransitionCollection;

    //--------------------------------------------------------------------------
    //
    //  CONSTRUCTOR
    //
    //--------------------------------------------------------------------------
    public function new() {}

	//--------------------------------------------------------------------------
	//
	//  PUBLIC METHODS
	//
	//--------------------------------------------------------------------------
	public function init():Void {
        currentState = UNINITIALIZED_STATE;
        _nameToStates = new StringMap<IState>();
        _notificationCache = new Array<Array<String>>();
	 	_observerCollection = new ObserverTransitionCollection();
	 	_observerCollection.init();
	}

	public function destroy():Void {
        for (key in _nameToStates.keys()) {
            _nameToStates.remove(key);
        }
        _nameToStates = null;
		_observerCollection.destroy();
		_observerCollection=null;
	}

	//----------------------------------
	//  IStateMachine
	//----------------------------------
    /**
	 * Adds a new state
	 * @param state The state to add
	 **/
    public function addState(state:IState):Void {
        if (_nameToStates.exists(state.name)) {
            removeState(state.name);
        }
        _nameToStates.set(state.name, state);
    }

    /**
	 * Removes a state by Unique ID
	 * @param state Unique ID
	 **/
    public function removeState(stateName:String):Void {
        _nameToStates.remove(stateName);
        if(currentState == stateName) {
            currentState = UNINITIALIZED_STATE;
        }
    }

    /**
	 * Removes all states.
	 **/
    public function flushStates():Void {
        for (uid in _nameToStates.keys()) {
            removeState(uid);
        }
    }

    /**
	 * Verifies if a state name is known by StateMachine.
	 *
	 * @param stateName	The name of the State
	 **/
    public function hasState(stateName:String):Bool {
        return stateName != null && _nameToStates.exists(stateName);
    }

    /**
	 * Gets all states Unique IDs
	 **/
    public function getAllStates():Array<String> {
        var names = new Array<String>();
        for (uid in _nameToStates.keys()) {
            names.push(uid);
        }
        return names;
    }

    /**
	 * Verifies if a transition can be made from the current state to the
	 * state passed as param
	 *
	 * @param stateName	The name of the State
	 **/
    public function canTransition(stateUID:String):Bool {
        return(hasState(stateUID)
        && stateUID != currentState
        && allowTransitionFrom(currentState, stateUID)
        );
    }

    /**
	 * Changes the current state
	 * This will only be done if the Intended state allows the transition from the current state
	 * Changing states will call the exit callback for the exiting state and enter callback for the entering state
	 * @param stateName	The name of the state to transition to
	 **/
    public function doTransition(stateName:String):Void {
        // If there is no state that matches stateTo
        if (!hasState(stateName)) {
            //trace("[StateMachine] Cannot make transition:State " + stateTo + " is not defined");
            return;
        }

        // If current state is not allowed to make this transition
        if (!canTransition(stateName)) {
            //trace("[StateMachine] Transition to " + stateName + " from " + currentState + " denied");
            notifyTransitionDenied(currentState, stateName, getAllFromsForStateByName(stateName));
            return;
        }

        // call exit and enter callbacks(if they exits)
        var path:Array<Int> = findPath(currentState, stateName);
        if (path[0] > 0) { // hasFroms
            //trace("[StateMachine] hasFroms");
            executeExitForStack(currentState, stateName, path[0]);
        }

        dumpNotificationCache();
        var oldState:String = currentState;
        currentState = stateName;
        if (path[1] > 0) { // hasTos
            //trace("[StateMachine] hasTos");
            _notificationCache.push([stateName, oldState]);
            executeEnterForStack(stateName, oldState);
        }
        dumpNotificationCache();
    }

    /**
	 * Sets the first state, calls enter callback and dispatches TRANSITION_COMPLETE
	 * These will only occour if no state is defined
	 * @param stateName	The UID of the State
	 **/
    public var initialState(default, set):String;
    private function set_initialState(stateName:String):String {
        if(currentState == UNINITIALIZED_STATE && _nameToStates.exists(stateName)) {
            currentState = stateName;
            executeEnterForStack(stateName, null);
            notifyTransitionComplete(stateName, null);
        }
        return initialState;
    }

    /**
	 *	Gets the Unique ID of the current state
	 */
    public var currentState(default, null):String;

    /**
	 * Verifies if a transition can be made from the current state to the
	 * state passed as param
	 *
	 * @param stateName	The name of the State
	 **/
    public function subscribe(observer:IObserverTransition):Void {
        _observerCollection.subscribe(observer);
    }

    /**
	 * Verifies if a transition can be made from the current state to the
	 * state passed as param
	 *
	 * @param stateName	The name of the State
	 **/
    public function unsubscribe(observer:IObserverTransition):Void {
        _observerCollection.unsubscribe(observer);
    }

    //--------------------------------------------------------------------------
	//
	//  PRIVATE METHODS
	//
	//--------------------------------------------------------------------------
	private function executeEnterForStack(stateTo:String, stateFrom:String):Void {
		var toStateTree:Array<IState> = getAllStatesChildToRootByName(stateTo);
        toStateTree.reverse();
        var fromStateTree:Array<IState> = getAllStatesChildToRootByName(stateFrom);
        for(i in 0...toStateTree.length) {
            var state:IState = toStateTree[i];
            // is this state in the last states tree
            if(fromStateTree.indexOf(state) >= 0) {
                // skip it as this state has already been entered
                continue;
            }
            state.enter(stateTo, stateFrom, state.name);
        }
	}

    private function executeExitForStack(state:String, stateTo:String, n:Int):Void {
        getStateByUID(state).exit(state, stateTo, state);
        var parentState:IState = getStateByUID(state);
        for (i in 0 ... n - 1) {
            parentState = getParentStateByName(parentState.name); // parentState.parent;
            parentState.exit(state, stateTo, parentState.name);
        }
    }

    private function dumpNotificationCache():Void {
        while(_notificationCache.length > 0) {
            var array:Array<String> = _notificationCache.shift();
            notifyTransitionComplete(array[0], array[1]);
        }
    }

	private function notifyTransitionComplete(toState:String, fromState:String):Void {
 	    _observerCollection.transitionComplete(toState, fromState);
	}
	
	private function notifyTransitionDenied(fromState:String, toState:String, allowedFromStates:Array<String>):Void {
		_observerCollection.transitionDenied(toState, fromState, allowedFromStates);
	}

    private function getAllStatesForState(stateName:String):Array<String> {
        var names = new Array<String>();
        var states:Array<IState> = getAllStatesChildToRootByName(stateName);
        for(state in states) {
            names.push(state.name);
        }
        return names;
    }

    /**
	 * Discovers the how many "exits" and how many "enters" are there between two
	 * given states and returns an array with these two Integers
	 * @param stateFrom The state to exit
	 * @param stateTo The state to enter
	 **/
    private function findPath(stateFrom:String, stateTo:String):Array<Int> {
        // Verifies if the states are in the same "branch" or have a common parent
        var froms:Int = 0;
        var tos:Int = 0;
        if (hasState(stateFrom) && hasState(stateTo)) {
            var fromState:IState = getStateByUID(stateFrom);
            while ((fromState != null) && (fromState != UNKNOWN_STATE) && (fromState != UNKNOWN_PARENT_STATE)) {
                tos = 0;
                var toState:IState = getStateByUID(stateTo);
                while ((toState != null) && (toState != UNKNOWN_STATE) && (toState != UNKNOWN_PARENT_STATE)) {
                    if (fromState==toState) {
                        // They are in the same brach or have
                        // a common parent Common parent
                        return [froms, tos];
                    }
                    tos++;
                    toState = getParentStateByName(toState.name); //toState.parent;
                }
                froms++;
                fromState = getParentStateByName(fromState.name); //fromState.parent;
            }
        }

        // No direct path, no commom parent:exit until root then enter until element
        var output:Array<Int> = [froms, tos];
        return output;
    }

    private function allowTransitionFrom(fromState:String, toState:String):Bool {
        var fromStateAllNames:Array<String> = getAllStatesForState(fromState);
        var toStateFroms:Array<String> = getAllFromsForStateByName(toState);
        return (toStateFroms.indexOf(WILDCARD) >= 0
        || doTransitionsMatch(fromStateAllNames, toStateFroms));
    }

	private function getAllStatesChildToRootByName(name:String):Array<IState> {
		var states:Array<IState> = new Array<IState>();
		while (hasState(name)) {
			var state:IState = getStateByUID(name);
			states.push(state);
			if (state.parentName == NO_PARENT) {
				break;
			}
			name = state.parentName;
		}
		return states;
	}
	
	private function doTransitionsMatch(fromStateAllNames:Array<String>, toStateFroms:Array<String>):Bool {
		for (name in fromStateAllNames) {
			if (toStateFroms.indexOf(name) < 0) {
				continue;
			}
			return true;
		}
		return false;
	}

    /**
	 * Gets a state by it's name
	 * @param name of the state
	 **/
    private function getStateByUID(name:String):IState {
        return hasState(name) ? _nameToStates.get(name) : UNKNOWN_STATE;
    }

	private function getAllFromsForStateByName(toState:String):Array<String> {
		var froms:Array<String> = new Array<String>();
		var states:Array<IState> = getAllStatesChildToRootByName(toState);
        var stop:Bool = false;
        for (state in states) {
            for (fromName in state.froms){
                if (froms.indexOf(fromName) < 0) {
					froms.push(fromName);
                    stop = true;
				}
			}
            if(stop) {
                break;
            }
		}
		return froms;
	}

    private function getParentStateByName(name:String):IState {
        if(!hasState(name)){
            return UNKNOWN_STATE;
        } else {
            var stateName:IState = getStateByUID(name);
            var parentName:String = stateName.parentName;
            if(parentName == NO_PARENT){
                return NO_PARENT_STATE;
            } else if(!hasState(parentName)){
                return UNKNOWN_PARENT_STATE;
            } else {
                return getStateByUID(parentName);
            }
        }
    }
}

private class NoopState implements IState {
    //--------------------------------------------------------------------------
    //
    //  CONSTRUCTOR
    //
    //--------------------------------------------------------------------------
    public function new(uid:String) {
        name = uid;
    }

    //----------------------------------
    //  IState
    //----------------------------------
    public var name(default, null):String;
    public var parentName(default, null):String;
    public var froms(default, null):Array<String>;
    public function enter(toState:String, fromState:String, currentState:String):Void {}
    public function exit(fromState:String, toState:String, currentState:String = null):Void {}
}