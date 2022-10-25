// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "./application"

import ClassSearchAutoCompleteController from "./class_search_auto_complete_controller"
application.register("class-search", ClassSearchAutoCompleteController)

import ContainerSplitterController from "./container_splitter_controller"
application.register("container-splitter", ContainerSplitterController)

import HistoryController from "./history_controller"
application.register("history", HistoryController)

import LoadChartController from "./load_chart_controller"
application.register("load-chart", LoadChartController)

import MetadataDownloaderController from "./metadata_downloader_controller"
application.register("metadata-downloader", MetadataDownloaderController)

import ShowModalController from "./show_modal_controller"
application.register("modal", ShowModalController)

import SimpleTreeController from "./simple_tree_controller"
application.register("simple-tree", SimpleTreeController)

import SkosCollectionColorsController from "./skos_collection_colors_controller"
application.register("skos-collection-colors", SkosCollectionColorsController)

import TurboModalController from "../../components/turbo_modal_component/turbo_modal_component_controller"
application.register("turbo-modal", TurboModalController)
import TurboFrameController from "./turbo_frame_controller"
application.register("turbo-frame", TurboFrameController)

import FormAutoCompleteController from "./form_auto_complete_controller"
application.register("form-auto-complete", FormAutoCompleteController)