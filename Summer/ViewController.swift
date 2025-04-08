//
//  ViewController.swift
//  Summer
//
//  Created by donghyun on 2021/05/30.
//

import UIKit

protocol ImageFilter {
    var name: String { get }
    
    func filter(image: UIImage) -> UIImage
}

extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

class FilterItemCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
}

struct Filter: ImageFilter {
    let name: String
    let identifier: String
    
    func filter(image: UIImage) -> UIImage {
        let context = CIContext(options: nil)
        let source = CIImage(image: image)

        let filter = CIFilter(name: identifier)
        
        filter?.setDefaults()
        filter?.setValue(source, forKey: kCIInputImageKey)
        
        let outputCGImage = context.createCGImage((filter?.outputImage!)!, from: (filter?.outputImage!.extent)!)

        let filteredImage = UIImage(cgImage: outputCGImage!)

        return filteredImage
    }
}

final class FilterManager {
    let filters: [ImageFilter] = [
        Filter(name: "Vivid", identifier: "CIPhotoEffectChrome"),
        Filter(name: "Fade", identifier: "CIPhotoEffectFade"),
        Filter(name: "Instant", identifier: "CIPhotoEffectInstant"),
        Filter(name: "Mono", identifier: "CIPhotoEffectMono"),
        Filter(name: "Noir", identifier: "CIPhotoEffectNoir"),
        Filter(name: "Process", identifier: "CIPhotoEffectProcess"),
        Filter(name: "Tonal", identifier: "CIPhotoEffectTonal"),
        Filter(name: "Transfer", identifier: "CIPhotoEffectTransfer"),
        Filter(name: "Curve", identifier: "CILinearToSRGBToneCurve"),
        Filter(name: "Linear", identifier: "CISRGBToneCurveToLinear")
    ]
}

class ViewController: UIViewController {
    private let filterManager = FilterManager()
    private var originalImage: UIImage = UIImage(named: "Sample")!
    private var selectedIndex: Int?
    
    private lazy var thumbnails: [UIImage] = {
        filterManager.filters.map{$0.filter(image: UIImage(named: "Thumbnail")!)}
    }()
    
    @IBOutlet weak private var photoView: UIImageView!
    @IBOutlet weak private var collectionView: UICollectionView!
    
    @IBOutlet weak private var photoViewLeading: NSLayoutConstraint!
    @IBOutlet weak private var photoViewTrailing: NSLayoutConstraint!
    
    @IBOutlet weak private var toolBar: UIToolbar!
    
    @IBOutlet weak private var maskView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.maskView.isHidden = true
        
        self.photoView.image = originalImage
        self.photoView.layer.cornerRadius = 4
        self.photoView.layer.masksToBounds = true
        self.photoView.layer.cornerCurve = .continuous
        
        self.toolBar.setShadowImage(UIImage(), forToolbarPosition: .bottom)
        
        self.toolBar.layer.shadowColor = UIColor.black.cgColor
        self.toolBar.layer.shadowRadius = 5
        self.toolBar.layer.shadowOpacity = 0.05
        self.toolBar.layer.shadowOffset = CGSize(width: 0, height: -10)
    }
    
    @IBAction func importPhoto() {

        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.delegate = self
        
        self.present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.sourceType = .camera
        imagePickerController.allowsEditing = true // 촬영 후 편집할 수 있는 부분이 나온다.
        imagePickerController.delegate = self
        
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func save() {
        guard let index = selectedIndex else { return }
        
        let controller = UIAlertController(title: "저장되었습니다", message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "확인", style: .default, handler: nil)
        controller.addAction(okAction)
        present(controller, animated: true, completion: nil)
        
        let filter = filterManager.filters[index]
        let image = filter.filter(image: originalImage)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

extension ViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let photo = info[.originalImage] as? UIImage {
            maskView.isHidden = false
            
            DispatchQueue.global(qos: .background).async {
                let resizedImage = photo.resize(to: CGSize(width: photo.size.width / 4, height: photo.size.height / 4))!
                
                DispatchQueue.main.async { [weak self] in
                    let horizontalSpacing: CGFloat = photo.size.width > photo.size.height ? 0 : 15
                    
                    self?.photoView.image = resizedImage
                    self?.selectedIndex = nil
                    self?.collectionView.reloadData()
                    self?.photoViewLeading.constant = horizontalSpacing
                    self?.photoViewTrailing.constant = horizontalSpacing
                    self?.originalImage = resizedImage
                    self?.maskView.isHidden = true
                }
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filterManager.filters.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterItemCell", for: indexPath) as! FilterItemCell
        
        cell.imageView.image = thumbnails[indexPath.row]
        cell.titleLabel.textColor = indexPath.item == selectedIndex ? .black : .lightGray
        cell.titleLabel.text = filterManager.filters[indexPath.item].name
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let filter = filterManager.filters[indexPath.item]
        
        let filteredImage = filter.filter(image: originalImage)
        
        self.photoView.image = filteredImage
        
        self.selectedIndex = indexPath.item
        self.collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 70, height: 100)
    }
}
