/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// PaletteBuilder.as
// John Maloney, September 2010
//
// PaletteBuilder generates the contents of the blocks palette for a given
// category, including the blocks, buttons, and watcher toggle boxes.

package scratch {
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	
	import blocks.Block;
	import blocks.BlockArg;
	
	import extensions.ScratchExtension;
	
	import translation.Translator;
	
	import ui.ProcedureSpecEditor;
	import ui.media.MediaLibrary;
	import ui.parts.UIPart;
	
	import uiwidgets.Button;
	import uiwidgets.DialogBox;
	import uiwidgets.IconButton;
	import uiwidgets.IndicatorLight;
	import uiwidgets.Menu;
	import uiwidgets.VariableSettings;

public class PaletteBuilder {

	protected var app:Scratch;
	protected var nextY:int;

	public function PaletteBuilder(app:Scratch) {
		this.app = app;
	}

	public static function strings():Array {
		return [
			'Stage selected:', 'No motion blocks',
			'Make a Block', 'Make a List', 'Make a Variable',
			'New List', 'List name', 'New Variable', 'Variable name',
			'New Block', 'Add an Extension'];
	}

	public function showBlocksForCategory(selectedCategory:int, scrollToOrigin:Boolean, shiftKey:Boolean = false):void {
		if (app.palette == null) return;
		app.palette.clear(scrollToOrigin);
		nextY = 7;

		if (selectedCategory == Specs.dataCategory) return showDataCategory();
		if (selectedCategory == Specs.myBlocksCategory) return showMyBlocksPalette(shiftKey);

		var catName:String = Specs.categories[selectedCategory][1];
		var catColor:int = Specs.blockColor(selectedCategory);
		if (app.viewedObj() && app.viewedObj().isStage) {
			// The stage has different blocks for some categories:
			var stageSpecific:Array = ['Control', 'Looks', 'Motion', 'Pen', 'Sensing'];
			if (stageSpecific.indexOf(catName) != -1) selectedCategory += 100;
			if (catName == 'Motion') {
				addItem(makeLabel(Translator.map('Stage selected:')));
				nextY -= 6;
				addItem(makeLabel(Translator.map('No motion blocks')));
				return;
			}
		}
		addBlocksForCategory(selectedCategory, catColor);
		updateCheckboxes();
	}

	private function addBlocksForCategory(category:int, catColor:int):void {
		var cmdCount:int;
		var targetObj:ScratchObj = app.viewedObj();
		for each (var spec:Array in Specs.commands) {
			if ((spec.length > 3) && (spec[2] == category)) {
				var blockColor:int = (app.interp.isImplemented(spec[3])) ? catColor : 0x505050;
				var defaultArgs:Array = targetObj.defaultArgsFor(spec[3], spec.slice(4));
				var label:String = spec[0];
				if(targetObj.isStage && spec[3] == 'whenClicked') label = 'when Stage clicked';
				var block:Block = new Block(label, spec[1], blockColor, spec[3], defaultArgs);
				var showCheckbox:Boolean = isCheckboxReporter(spec[3]);
				if (showCheckbox) addReporterCheckbox(block);
				addItem(block, showCheckbox);
				cmdCount++;
			} else {
				if ((spec.length == 1) && (cmdCount > 0)) nextY += 10 * spec[0].length; // add some space
				cmdCount = 0;
			}
		}
	}

	protected function addItem(o:DisplayObject, hasCheckbox:Boolean = false):void {
		o.x = hasCheckbox ? 23 : 6;
		o.y = nextY;
		app.palette.addChild(o);
		app.palette.updateSize();
		nextY += o.height + 5;
	}

	private function makeLabel(label:String):TextField {
		var t:TextField = new TextField();
		t.autoSize = TextFieldAutoSize.LEFT;
		t.selectable = false;
		t.background = false;
		t.text = label;
		t.setTextFormat(CSS.normalTextFormat);
		return t;
	}

	private function showMyBlocksPalette(shiftKey:Boolean):void {
		// show creation button, hat, and call blocks
		var catColor:int = Specs.blockColor(Specs.procedureColor);

		// For Game Snap, focus area blocks
		if (app.canAddFocusAreaBlocks) {
			addBlocksForCategory(Specs.focusAreaCategory, Specs.focusAreaColor);
		}

		// For Game Snap, added this label to separate this section from the global section below
		var localBlocksLabel:TextField = makeLabel("Local Custom Blocks ");
		if(app.viewedObj() == app.stagePane.globalObjSprite()) {
			localBlocksLabel = makeLabel("Global Custom Blocks ");
		}
		localBlocksLabel.x = 5;
		localBlocksLabel.y = nextY;
		app.palette.addChild(localBlocksLabel);
		addLine(localBlocksLabel.x + localBlocksLabel.width, nextY + (localBlocksLabel.height / 2), pwidth - x - 38 - localBlocksLabel.width);
		nextY += localBlocksLabel.height + 9;

		addItem(new Button(Translator.map('Make a Block'), makeNewBlock, false, '/help/studio/tips/blocks/make-a-block/'));
		
		var definitions:Array = app.viewedObj().procedureDefinitions();
		if (definitions.length > 0) {
			nextY += 5;
			for each (var proc:Block in definitions) {
				var b:Block = new Block(proc.spec, ' ', Specs.procedureColor, Specs.CALL, proc.defaultArgValues);
				
				// For Game Snap, if this is a local block to the global object, then be sure to mark this procedure block as global as well
				if(app.viewedObj() == app.stagePane.globalObjSprite()) {
					b.isGlobal = true;
				}
				
				addItem(b);
			}
			nextY += 5;
		}

		var x:int = 5;
		
		// For Game Snap, add template object blocks here
		if(app.viewedObj().basedOnTemplateObj != null) {
			// Add the template object definitions
			nextY += 9;
			
			var templateBlockLabel:TextField = makeLabel("Template Custom Blocks ");
			templateBlockLabel.x = x;
			templateBlockLabel.y = nextY;
			app.palette.addChild(templateBlockLabel);
			
			addLine(templateBlockLabel.x + templateBlockLabel.width, nextY + (templateBlockLabel.height / 2), pwidth - x - 38 - templateBlockLabel.width);
			
			nextY += templateBlockLabel.height + 9;
			
			definitions = app.viewedObj().basedOnTemplateObj.procedureDefinitions();
			if (definitions.length > 0) {
				nextY += 5;
				for each (proc in definitions) {
					b = new Block(proc.spec, ' ', Specs.procedureColor, Specs.CALL, proc.defaultArgValues);
					b.fromTemplateObj = true;
					addItem(b);
				}
				nextY += 5;
			}
		}
		
		// For Game Snap, add global blocks here
		if(app.stagePane.globalObjSprite() && app.viewedObj() != app.stagePane.globalObjSprite() && app.stagePane.globalObjSprite().procedureDefinitions().length > 0) {
			// Add the global block definitions.
			nextY += 9;
			
			var globalBlockLabel:TextField = makeLabel("Global Custom Blocks ");
			globalBlockLabel.x = x;
			globalBlockLabel.y = nextY;
			app.palette.addChild(globalBlockLabel);
			
			addLine(globalBlockLabel.x + globalBlockLabel.width, nextY + (globalBlockLabel.height / 2), pwidth - x - 38 - globalBlockLabel.width);
			
			nextY += globalBlockLabel.height + 9;
			
			definitions = app.stagePane.globalObjSprite().procedureDefinitions();
			if (definitions.length > 0) {
				nextY += 5;
				for each (proc in definitions) {
					b = new Block(proc.spec, ' ', Specs.procedureColor, Specs.CALL, proc.defaultArgValues);
					b.isGlobal = true;
					addItem(b);
				}
				nextY += 5;
			}
		}
		
		addExtensionButtons();
		for each (var ext:* in app.extensionManager.enabledExtensions()) {
			addExtensionSeparator(ext);
			addBlocksForExtension(ext);
		}

		updateCheckboxes();
	}

	protected function addExtensionButtons():void {
	}

	protected function addAddExtensionButton():void {
		addItem(new Button(Translator.map('Add an Extension'), showAnExtension, false, '/help/studio/tips/blocks/add-an-extension/'));
	}

	private function showDataCategory():void {
		var catColor:int = Specs.variableColor;

		// Add the variables by string for Game Snap
		if(app.viewedObj().isGlobalObj || app.showDataByStringBlocks) {
			addBlocksForCategory(Specs.dataSpecialCategory, catColor);
			nextY += 15;
		}
		
		// variable buttons, reporters, and set/change blocks
		var x:int = 5;
		if(!app.viewedObj().isGlobalObj) {	// Added this check for Game Snap
			addItem(new Button(Translator.map('Make a Variable'), makeVariable));
			
			// For Game Snap, split up the variables between Local and Global

			// Local variables, if any
			var varLocalNames:Array = app.runtime.allLocalVarNames().sort();
			if(varLocalNames.length > 0) {
				var labelAdded:Boolean = false;

				// Go through the variables
				for each (var n:String in varLocalNames) {
					// For Game Snap, only add a local variable that isn't in the template object variable list
					if(app.runtime.allTemplateVarNames().indexOf(n) == -1) {
						// If we haven't added the label yet, do so now
						if(!labelAdded) {
							labelAdded = true;
							var localVarLabel:TextField = makeLabel("Local Variables ");
							localVarLabel.x = 5;
							localVarLabel.y = nextY;
							app.palette.addChild(localVarLabel);
							addLine(localVarLabel.x + localVarLabel.width, nextY + (localVarLabel.height / 2), pwidth - x - 38 - localVarLabel.width);
							nextY += localVarLabel.height;
						}
						addVariableCheckbox(n, false);
						addItem(new Block(n, 'r', catColor, Specs.GET_VAR), true);
					}
				}
				//nextY += 10;
			}
			
			// Template variables, if any
			var varTemplateNames:Array = app.runtime.allTemplateVarNames().sort();
			if(varTemplateNames.length > 0) {
				// First add a label
				var templateVarLabel:TextField = makeLabel("Template Variables ");
				templateVarLabel.x = 5;
				templateVarLabel.y = nextY;
				app.palette.addChild(templateVarLabel);
				addLine(templateVarLabel.x + templateVarLabel.width, nextY + (templateVarLabel.height / 2), pwidth - x - 38 - templateVarLabel.width);
				nextY += templateVarLabel.height;
				
				// Now the variables themselves
				for each (var n:String in varTemplateNames) {
					addVariableCheckbox(n, false);
					var tb:Block = new Block(n, 'r', catColor, Specs.GET_VAR);
					tb.fromTemplateObj = true;
					addItem(tb, true);
				}
			}
			
			// Global variables, if any
			var varGlobalNames:Array = app.runtime.allGlobalVarNames().sort();
			if(varGlobalNames.length > 0) {
				// First add a label
				var globalVarLabel:TextField = makeLabel("Global Variables ");
				globalVarLabel.x = 5;
				globalVarLabel.y = nextY;
				app.palette.addChild(globalVarLabel);
				addLine(globalVarLabel.x + globalVarLabel.width, nextY + (globalVarLabel.height / 2), pwidth - x - 38 - globalVarLabel.width);
				nextY += globalVarLabel.height;
				
				// Now the variables themselves
				for each (var n:String in varGlobalNames) {
					addVariableCheckbox(n, false);
					addItem(new Block(n, 'r', catColor, Specs.GET_VAR), true);
				}
				//nextY += 10;
			}
			
			// Now the variable code blocks
			if(varLocalNames.length > 0 || varTemplateNames.length > 0 || varGlobalNames.length > 0) {
				nextY += 2;
				addLine(x, nextY, pwidth - x - 38);
				nextY += 7;
				addBlocksForCategory(Specs.dataCategory, catColor);
				nextY += 15;
			}
			
			// Original code here:
			//var varNames:Array = app.runtime.allVarNames().sort();
			//if (varNames.length > 0) {
			//	for each (var n:String in varNames) {
			//		addVariableCheckbox(n, false);
			//		addItem(new Block(n, 'r', catColor, Specs.GET_VAR), true);
			//	}
			//	nextY += 10;
			//	addBlocksForCategory(Specs.dataCategory, catColor);
			//	nextY += 15;
			//}
		}
		
		// lists
		catColor = Specs.listColor;
		
		// Add the lists by string for Game Snap
		if(app.viewedObj().isGlobalObj || app.showDataByStringBlocks) {
			addBlocksForCategory(Specs.listSpecialCategory, catColor);
			nextY += 15;
		}

		if(!app.viewedObj().isGlobalObj) {	// Added this check for Game Snap
			addItem(new Button(Translator.map('Make a List'), makeList));
			
			// For Game Snap, split up the lists between Local and Global
			
			// Local lists, if any
			var listLocalNames:Array = app.runtime.allLocalListNames().sort();
			if(listLocalNames.length > 0) {
				// First add a label
				var localListLabel:TextField = makeLabel("Local Lists ");
				localListLabel.x = 5;
				localListLabel.y = nextY;
				app.palette.addChild(localListLabel);
				addLine(localListLabel.x + localListLabel.width, nextY + (localListLabel.height / 2), pwidth - x - 38 - localListLabel.width);
				nextY += localListLabel.height;
				
				// Now the lists themselves
				for each (var n:String in listLocalNames) {
					addVariableCheckbox(n, true);
					addItem(new Block(n, 'r', catColor, Specs.GET_LIST), true);
				}
			}
			
			// Global lists, if any
			var listGlobalNames:Array = app.runtime.allGlobalListNames().sort();
			if(listGlobalNames.length > 0) {
				// First add a label
				var globalListLabel:TextField = makeLabel("Global Lists ");
				globalListLabel.x = 5;
				globalListLabel.y = nextY;
				app.palette.addChild(globalListLabel);
				addLine(globalListLabel.x + globalListLabel.width, nextY + (globalListLabel.height / 2), pwidth - x - 38 - globalListLabel.width);
				nextY += globalListLabel.height;
				
				// Now the lists themselves
				for each (var n:String in listGlobalNames) {
					addVariableCheckbox(n, true);
					addItem(new Block(n, 'r', catColor, Specs.GET_LIST), true);
				}
			}
			
			// Now the list code blocks
			if(listLocalNames.length > 0 || listGlobalNames.length > 0) {
				nextY += 2;
				addLine(x, nextY, pwidth - x - 38);
				nextY += 7;
				addBlocksForCategory(Specs.listCategory, catColor);
				nextY += 15;
			}

			// Original code:
			//var listNames:Array = app.runtime.allListNames().sort();
			//if (listNames.length > 0) {
			//	for each (n in listNames) {
			//		addVariableCheckbox(n, true);
			//		addItem(new Block(n, 'r', catColor, Specs.GET_LIST), true);
			//	}
			//	nextY += 10;
			//	addBlocksForCategory(Specs.listCategory, catColor);
			//}
		}
		
		updateCheckboxes();
	}

	protected function createVar(name:String, varSettings:VariableSettings):* {
		var obj:ScratchObj = (varSettings.isLocal) ? app.viewedObj() : app.stageObj();
		if (obj.hasName(name)) {
			DialogBox.notify("Cannot Add", "That name is already in use.");
			return;
		}
		var variable:* = (varSettings.isList ? obj.lookupOrCreateList(name) : obj.lookupOrCreateVar(name));

		app.runtime.showVarOrListFor(name, varSettings.isList, obj);
		app.setSaveNeeded();

		return variable;
	}

	private function makeVariable():void {
		function makeVar2():void {
			var n:String = d.getField('Variable name').replace(/^\s+|\s+$/g, '');
			if (n.length == 0) return;

			createVar(n, varSettings);
		}

		var d:DialogBox = new DialogBox(makeVar2);
		var varSettings:VariableSettings = makeVarSettings(false, app.viewedObj().isStage);
		d.addTitle('New Variable');
		d.addField('Variable name', 150);
		d.addWidget(varSettings);
		d.addAcceptCancelButtons('OK');
		d.showOnStage(app.stage);
	}

	private function makeList():void {
		function makeList2(d:DialogBox):void {
			var n:String = d.getField('List name').replace(/^\s+|\s+$/g, '');
			if (n.length == 0) return;

			createVar(n, varSettings);
		}
		var d:DialogBox = new DialogBox(makeList2);
		var varSettings:VariableSettings = makeVarSettings(true, app.viewedObj().isStage);
		d.addTitle('New List');
		d.addField('List name', 150);
		d.addWidget(varSettings);
		d.addAcceptCancelButtons('OK');
		d.showOnStage(app.stage);
	}

	protected function makeVarSettings(isList:Boolean, isStage:Boolean):VariableSettings {
		return new VariableSettings(isList, isStage);
	}

	private function makeNewBlock():void {
		function addBlockHat(dialog:DialogBox):void {
			var spec:String = specEditor.spec().replace(/^\s+|\s+$/g, '');
			if (spec.length == 0) return;
			var newHat:Block = new Block(spec, 'p', Specs.procedureColor, Specs.PROCEDURE_DEF);
			newHat.parameterNames = specEditor.inputNames();
			newHat.defaultArgValues = specEditor.defaultArgValues();
			newHat.warpProcFlag = specEditor.warpFlag();
			newHat.setSpec(spec);
			newHat.x = 10 - app.scriptsPane.x + Math.random() * 100;
			newHat.y = 10 - app.scriptsPane.y + Math.random() * 100;
			
			// For Game Snap
			if(app.viewedObj().isGlobalObj) {
				newHat.isGlobal = true;
			}
			
			app.scriptsPane.addChild(newHat);
			app.scriptsPane.saveScripts();
			app.runtime.updateCalls();
			app.updatePalette();
			app.setSaveNeeded();
		}
		var specEditor:ProcedureSpecEditor = new ProcedureSpecEditor('', [], false);
		var d:DialogBox = new DialogBox(addBlockHat);
		d.addTitle('New Block');
		d.addWidget(specEditor);
		d.addAcceptCancelButtons('OK');
		d.showOnStage(app.stage, true);
		specEditor.setInitialFocus();
	}

	private function showAnExtension():void {
		function addExt(ext:ScratchExtension):void {
			if (ext.isInternal) {
				app.extensionManager.setEnabled(ext.name, true);
			} else {
				app.extensionManager.loadCustom(ext);
			}
			app.updatePalette();
		}
		var lib:MediaLibrary = app.getMediaLibrary('extension', addExt);
		lib.open();
	}

	protected function addReporterCheckbox(block:Block):void {
		var b:IconButton = new IconButton(toggleWatcher, 'checkbox');
		b.disableMouseover();
		var targetObj:ScratchObj = isSpriteSpecific(block.op) ? app.viewedObj() : app.stagePane;
		b.clientData = {
			type: 'reporter',
			targetObj: targetObj,
			cmd: block.op,
			block: block,
			color: block.base.color
		};
		b.x = 6;
		b.y = nextY + 5;
		app.palette.addChild(b);
	}

	protected function isCheckboxReporter(op:String):Boolean {
		const checkboxReporters: Array = [
			'xpos', 'ypos', 'heading', 'costumeIndex', 'costumeCount', 'scale', 'volume', 'timeAndDate',	// Added 'costumeCount' for Game Snap
			'backgroundIndex', 'sceneName', 'tempo', 'answer', 'timer', 'soundLevel', 'isLoud',
			'sensor:', 'sensorPressed:', 'senseVideoMotion', 'xScroll', 'yScroll',
			'getDistance', 'getTilt'];
		return checkboxReporters.indexOf(op) > -1;
	}

	private function isSpriteSpecific(op:String):Boolean {
		const spriteSpecific: Array = ['costumeIndex', 'costumeCount', 'xpos', 'ypos', 'heading', 'scale', 'volume'];	// Added 'costumeCount' for Game Snap
		return spriteSpecific.indexOf(op) > -1;
	}

	private function getBlockArg(b:Block, i:int):String {
		var arg:BlockArg = b.args[i] as BlockArg;
		if (arg) return arg.argValue;
		return '';
	}

	private function addVariableCheckbox(varName:String, isList:Boolean):void {
		var b:IconButton = new IconButton(toggleWatcher, 'checkbox');
		b.disableMouseover();
		var targetObj:ScratchObj = app.viewedObj();
		if (isList) {
			if (targetObj.listNames().indexOf(varName) < 0) targetObj = app.stagePane;
		} else {
			if (targetObj.varNames().indexOf(varName) < 0) targetObj = app.stagePane;
		}
		b.clientData = {
			type: 'variable',
			isList: isList,
			targetObj: targetObj,
			varName: varName
		};
		b.x = 6;
		b.y = nextY + 5;
		app.palette.addChild(b);
	}

	private function toggleWatcher(b:IconButton):void {
		var data:Object = b.clientData;
		if (data.block) {
			switch (data.block.op) {
			case 'senseVideoMotion':
				data.targetObj = getBlockArg(data.block, 1) == 'Stage' ? app.stagePane : app.viewedObj();
			case 'sensor:':
			case 'sensorPressed:':
			case 'timeAndDate':
				data.param = getBlockArg(data.block, 0);
				break;
			}
		}
		var showFlag:Boolean = !app.runtime.watcherShowing(data);
		app.runtime.showWatcher(data, showFlag);
		b.setOn(showFlag);
		app.setSaveNeeded();
	}

	private function updateCheckboxes():void {
		for (var i:int = 0; i < app.palette.numChildren; i++) {
			var b:IconButton = app.palette.getChildAt(i) as IconButton;
			if (b && b.clientData) {
				b.setOn(app.runtime.watcherShowing(b.clientData));
			}
		}
	}

	protected function getExtensionMenu(ext:ScratchExtension):Menu {
		function showAbout():void {
			// Open in the tips window if the URL starts with /info/ and another tab otherwise
			if (ext.url) {
				if (ext.url.indexOf('/info/') === 0) app.showTip(ext.url);
				else if(ext.url.indexOf('http') === 0) navigateToURL(new URLRequest(ext.url));
				else DialogBox.notify('Extensions', 'Unable to load about page: the URL given for extension "' + ext.name + '" is not formatted correctly.');
			}
		}
		function hideExtension():void {
			app.extensionManager.setEnabled(ext.name, false);
			app.updatePalette();
		}

		var m:Menu = new Menu();
		m.addItem(Translator.map('About') + ' ' + ext.name + ' ' + Translator.map('extension') + '...', showAbout, !!ext.url);
		m.addItem('Remove extension blocks', hideExtension);
		return m;
	}

	protected const pwidth:int = 215;
	protected function addExtensionSeparator(ext:ScratchExtension):void {
		function extensionMenu(ignore:*):void {
			var m:Menu = getExtensionMenu(ext);
			m.showOnStage(app.stage);
		}
		nextY += 7;

		var titleButton:IconButton = UIPart.makeMenuButton(ext.name, extensionMenu, true, CSS.textColor);
		titleButton.x = 5;
		titleButton.y = nextY;
		app.palette.addChild(titleButton);

		addLineForExtensionTitle(titleButton, ext);

		var indicator:IndicatorLight = new IndicatorLight(ext);
		indicator.addEventListener(MouseEvent.CLICK, function(e:Event):void {Scratch.app.showTip('extensions');}, false, 0, true);
		app.extensionManager.updateIndicator(indicator, ext);
		indicator.x = pwidth - 30;
		indicator.y = nextY + 2;
		app.palette.addChild(indicator);

		nextY += titleButton.height + 10;
	}

	protected function addLineForExtensionTitle(titleButton:IconButton, ext:ScratchExtension):void {
		var x:int = titleButton.width + 12;
		addLine(x, nextY + 9, pwidth - x - 38);
	}

	private function addBlocksForExtension(ext:ScratchExtension):void {
		var blockColor:int = Specs.extensionsColor;
		var opPrefix:String = ext.useScratchPrimitives ? '' : ext.name + '.';
		for each (var spec:Array in ext.blockSpecs) {
			if (spec.length >= 3) {
				var op:String = opPrefix + spec[2];
				var defaultArgs:Array = spec.slice(3);
				var block:Block = new Block(spec[1], spec[0], blockColor, op, defaultArgs);
				var showCheckbox:Boolean = (spec[0] == 'r' && defaultArgs.length == 0);
				if (showCheckbox) addReporterCheckbox(block);
				addItem(block, showCheckbox);
			} else {
				if (spec.length == 1) nextY += 10 * spec[0].length; // add some space
			}
		}
	}

	protected function addLine(x:int, y:int, w:int):void {
		const light:int = 0xF2F2F2;
		const dark:int = CSS.borderColor - 0x141414;
		var line:Shape = new Shape();
		var g:Graphics = line.graphics;

		g.lineStyle(1, dark, 1, true);
		g.moveTo(0, 0);
		g.lineTo(w, 0);

		g.lineStyle(1, light, 1, true);
		g.moveTo(0, 1);
		g.lineTo(w, 1);
		line.x = x;
		line.y = y;
		app.palette.addChild(line);
	}

}}
