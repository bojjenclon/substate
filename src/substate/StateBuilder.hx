/****
* 
*    substate
*    =================================
*    A Single Hierarchical State Machine
* 
*               |_
*         _____|~ |______ ,.
*        ( --  subSTATE  `+|
*      ~~~~~~~~~~~~~~~~~~~~~~~
* 
* Copyright (c) 2014 Infinite Descent. All rights reserved.
* 
* Redistribution and use in source and binary forms, with or without modification, are
* permitted provided that the following conditions are met:
* 
*   1. Redistributions of source code must retain the above copyright notice, this list of
*      conditions and the following disclaimer.
* 
*   2. Redistributions in binary form must reproduce the above copyright notice, this list
*      of conditions and the following disclaimer in the documentation and/or other materials
*      provided with the distribution.
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
****/

package substate;

import substate.SubStateMachine;

class StateBuilder<T> {
    //----------------------------------
    //  CONSTS
    //----------------------------------
    private static var NO_ENTER:IEnter = new NoopEnter();
    private static var NO_UPDATE:IUpdateable = new NoopUpdate();
    private static var NO_EXIT:IExit = new NoopExit();

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
    public function build(stateName:String, params:Dynamic = null):IState<T> {
        if (params == null ){
            params = {};
        }

        var parentName = Reflect.hasField(params, "parent") ? cast Reflect.getProperty(params, "parent") : SubStateMachine.NO_PARENT;
        var froms = getFroms(params);
        var owner = Reflect.hasField(params, "owner") ? cast Reflect.getProperty(params, "owner") : null;
        var onEnter = Reflect.hasField(params, "enter") ? cast Reflect.getProperty(params, "enter") : NO_ENTER;
        var onUpdate = Reflect.hasField(params, "update") ? cast Reflect.getProperty(params, "update") : NO_UPDATE;
        var onExit = Reflect.hasField(params, "exit") ? cast Reflect.getProperty(params, "exit") : NO_EXIT;

        return new BuiltState<T>(
            stateName,
            parentName,
            froms,
            owner,
            onEnter,
            onUpdate,
            onExit
        );
    }

    //--------------------------------------------------------------------------
    //
    //  PRIVATE METHODS
    //
    //--------------------------------------------------------------------------
    private function getFroms(data:Dynamic):Array<String> {
        var froms:Array<String> = new Array<String>();
        if(Reflect.hasField(data, "from")) {
            var fromData:String = cast Reflect.getProperty(data, "from");
            froms = Std.string(fromData).split(",");
        }
        return froms;
    }
}

private class BuiltState<T> implements IState<T> {
    //----------------------------------
    //  vars
    //----------------------------------
    private var _onEnter:IEnter;
    private var _onUpdate:IUpdateable;
    private var _onExit:IExit;

    //--------------------------------------------------------------------------
    //
    //  CONSTRUCTOR
    //
    //--------------------------------------------------------------------------
    public function new(stateName:String, stateParentName:String, stateFroms:Array<String>, stateOwner:T, enter:IEnter, update:IUpdateable, exit:IExit) {
        name = stateName;
        parentName = stateParentName;
        froms = stateFroms;
        owner = stateOwner;
        _onEnter = enter;
        _onUpdate = update;
        _onExit = exit;
    }

    //----------------------------------
    //  IState
    //----------------------------------
    public var name(default, null):String;
    public var parentName(default, null):String;
    public var froms(default, null):Array<String>;
    public var owner(default, null):T;

    public function enter(toState:String, fromState:String, currentState:String):Void {
        _onEnter.enter(toState, fromState, currentState);
    }

    public function update(dt:Float, currentState:String = null):Void {
        _onUpdate.update(dt, currentState);
    }

    public function exit(fromState:String, toState:String, currentState:String = null):Void {
        _onExit.exit(fromState, toState, currentState);
    }
}

private class NoopEnter implements IEnter {
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
    //----------------------------------
    //  IState
    //----------------------------------
    public function enter(toState:String, fromState:String, currentState:String):Void {
        //
    }
}

private class NoopUpdate implements IUpdateable {
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
    //----------------------------------
    //  IState
    //----------------------------------
    public function update(dt:Float, currentState:String = null):Void {
        //
    }
}

private class NoopExit implements IExit {
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
    //----------------------------------
    //  IState
    //----------------------------------
    public function exit(fromState:String, toState:String, currentState:String = null):Void {
        //
    }
}
