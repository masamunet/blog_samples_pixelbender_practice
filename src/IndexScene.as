package {
	import jp.progression.commands.display.AddChildAt;
	import jp.progression.scenes.SceneObject;
	
	import net.hires.debug.Stats;
	
	/**
	 * ...
	 * @author ...
	 */
	public class IndexScene extends SceneObject {
		
		private var _page:IndexPage;
		private var _message:Message;
		private var _stats:Stats;
		/**
		 * 新しい IndexScene インスタンスを作成します。
		 */
		public function IndexScene() {
			// シーンタイトルを設定します。
			title = "pixelBender_test";
		}
		
		/**
		 * シーン移動時に目的地がシーンオブジェクト自身もしくは子階層だった場合に、階層が変更された直後に送出されます。
		 * このイベント処理の実行中には、ExecutorObject を使用した非同期処理が行えます。
		 */
		override protected function atSceneLoad():void {
			_page = new IndexPage();
			_message = new Message();
			_stats = new Stats();
			addCommand(
				new AddChildAt(container, _page, 10),
				new AddChildAt(container, _message, 15),
				new AddChildAt(container, _stats, 20)
			);
		}
	}
}
