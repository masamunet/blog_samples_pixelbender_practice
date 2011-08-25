package
{
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	
	import jp.progression.casts.CastTextField;
	
	public class Message extends CastTextField
	{
		public function Message(initObject:Object=null)
		{
			super(initObject);
			var textFormat:TextFormat = new TextFormat("_等幅", 16, 0xFFFFFF, true);
			defaultTextFormat = textFormat;
			selectable = false;
			autoSize = TextFieldAutoSize.LEFT;
			mouseEnabled = false;
		}
		
		private function _onStageResizeHandler(e:Event):void
		{
			switch(stage.displayState){
				case StageDisplayState.NORMAL:
					_setText("クリックでフルスクリーンに。");
					break;
				case StageDisplayState.FULL_SCREEN:
					_setText("クリックで戻る。");
					break;
			}
		}
		
		private function _setText(message:String):void
		{
			text = message;
			x = (stage.stageWidth - width) * 0.5;
			y = (stage.stageHeight - height) * 0.5;
		}


		protected override function atCastAdded():void
		{
			_setText("クリックでフルスクリーンに。");
			stage.addEventListener(Event.RESIZE, _onStageResizeHandler);
		}

		protected override function atCastRemoved():void
		{
			stage.removeEventListener(Event.RESIZE, _onStageResizeHandler);
		}

	}
}