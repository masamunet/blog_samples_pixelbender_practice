package
{
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import jp.progression.casts.CastSprite;
	import jp.progression.commands.display.AddChild;
	import jp.progression.commands.display.RemoveAllChildren;
	import jp.utweb.shaders.ShallowWaterContainer2;
	
	public class IndexPage extends CastSprite
	{
		private var _innerCamera:InnerCamera;
		private var _rippler:ShallowWaterContainer2;

		private static const _GRID_W:int = 150;
		private static const _GRID_H:int = 150;
		protected override function atCastAdded():void
		{
			var target:IndexPage = this;
			_innerCamera = new InnerCamera();
			addCommand(
				new AddChild(this, _innerCamera),
				function():void{
					_rippler = new ShallowWaterContainer2(_innerCamera.width, _innerCamera.height, _GRID_W, _GRID_H);
					_rippler.timeStep = 1;
					_rippler.viscosity = 0.2;
					_rippler.drag = 0.01;
					_rippler.relaxation = 0.15;
					_rippler.relaxationSteps = 2;
					_rippler.filterTarget = _innerCamera;
					stage.addEventListener(MouseEvent.MOUSE_MOVE, _onMouseMoveHadler);
					stage.addEventListener(MouseEvent.MOUSE_UP, _onMouseUpHandler);
					_innerCamera.addEventListener(InnerCamera.CAMERA_READY, _onCameraReadyHandler);
					insertCommand(
						new AddChild(target, _rippler)
					);
				},
				_setPosition
			);
		}
		
		private function _onCameraReadyHandler(e:Event):void
		{
			_rippler.drawStart();
		}
		
		private function _onMouseUpHandler(e:MouseEvent):void
		{
			stage.addEventListener(Event.RESIZE, _onStageResizeHandler);
			switch(stage.displayState){
				case StageDisplayState.FULL_SCREEN:
					stage.displayState = StageDisplayState.NORMAL;
					break;
				case StageDisplayState.NORMAL:
					stage.displayState = StageDisplayState.FULL_SCREEN;
					break;
				default:
					stage.displayState = StageDisplayState.NORMAL;
					break;
			}
		}
		
		private function _onStageResizeHandler(e:Event):void
		{
			stage.removeEventListener(Event.RESIZE, _onStageResizeHandler);
			_setPosition();
		}
		
		private function _setPosition():void
		{
			width = stage.stageWidth;
			scaleY = scaleX;
			y = (stage.stageHeight - height) * 0.5;
			//
			scaleX *= -1;
			x = width;
		}
		
		private var _oldX : Number;
		private var _oldY : Number;
		
		private function _onMouseMoveHadler(event:MouseEvent):void
		{
			var mX:Number = stage.mouseX;
			var mY:Number = stage.mouseY;
			mX = stage.stageWidth - mX;
			mX *= _rippler.width / stage.stageWidth;
			mY *= _rippler.height / stage.stageHeight;
			_rippler.addVelocity(
				mX, mY,
				mX-_oldX, mY-_oldY,
				5, 1);
			_oldX = mX;
			_oldY = mX;
			_rippler.addPressure(mX, mY, 7, 1);
		}

		protected override function atCastRemoved():void
		{
			addCommand(
				new RemoveAllChildren(this),
				function():void{
					stage.removeEventListener(MouseEvent.MOUSE_MOVE, _onMouseMoveHadler);
					stage.removeEventListener(MouseEvent.MOUSE_UP, _onMouseUpHandler);
					stage.removeEventListener(Event.RESIZE, _onStageResizeHandler);
					_rippler.drawStop();
					_rippler = null;
					_innerCamera.removeEventListener(InnerCamera.CAMERA_READY, _onCameraReadyHandler);
					_innerCamera = null;
				}
			);
		}


		public function IndexPage(initObject:Object=null)
		{
			super(initObject);
		}
	}
}