//
//  ViewController.swift
//  Stocks
//
//  Created by Artem Vinnik on 12.09.2018.
//  Copyright © 2018 Daniel Kunis. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var logoImageView: UIImageView!
    
    // MARK: - private properties
    
    private var companies: [String: String] = [:]
    
    // MARK: - Privte methods
    
    private func requestQuote(for symbol: String) {
        let url = URL(string: "https://api.iextrading.com/1.0/stock/\(symbol)/quote")!
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
            else {
                    self.alertNetworkError()
                    return
            }
            
            self.parseQuote(data: data)
        }
        
        dataTask.resume()
        
        let imageURl = URL(string: "https://storage.googleapis.com/iex/api/logos/\(symbol).png")!
        
        let imageTask = URLSession.shared.dataTask(with: imageURl) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    self.alertNetworkError()
                    return
            }
            
            DispatchQueue.main.async {
                self.logoImageView.image = UIImage(data: data)
            }
        }
        
        imageTask.resume()
    }
    
    private func requestCompanyList() {
        self.activityIndicator.startAnimating()
        
        let url = URL(string: "https://api.iextrading.com/1.0/stock/market/list/infocus")!
        
        let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
            else {
                    self.alertNetworkError()
                    return
            }
            
            self.parseCompanyList(data: data)
        }
        
        dataTask.resume()
    }
    
    private func parseCompanyList(data: Data) {
        struct Company: Decodable {
            let companyName: String
            let symbol: String
        }
        
        do {
            let companies = try JSONDecoder().decode([Company].self, from: data)
            for company in companies {
                self.companies[company.companyName] = company.symbol
            }
            
            DispatchQueue.main.async {
                self.companyPickerView.reloadAllComponents()
                self.requestQuoteUpdate()
            }
        } catch {
            self.alertJSONError()
        }
    }
    
    private func parseQuote(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double
            else {
                self.alertJSONError()
                return
            }
            
            DispatchQueue.main.async {
                self.displayStockInfo(companyName: companyName,
                                      symbol: companySymbol,
                                      price: price,
                                      priceChange: priceChange)
            }
        } catch {
            self.alertJSONError()
        }
    }
    
    private func displayStockInfo(companyName: String, symbol: String, price: Double, priceChange: Double) {
        self.activityIndicator.stopAnimating()
        self.companyNameLabel.text = companyName
        self.companyNameLabel.font = UIFont.boldSystemFont(ofSize: self.companyNameLabel.font.pointSize)
        self.companySymbolLabel.text = symbol
        self.priceLabel.text = "\(price)"
        self.priceChangeLabel.text = "\(priceChange)"
        
        if priceChange < 0 {
            self.priceChangeLabel.textColor = UIColor.red
        } else if priceChange == 0 {
            self.priceChangeLabel.textColor = UIColor.black
        } else {
            self.priceChangeLabel.textColor = UIColor.green
        }
    }
    
    private func requestQuoteUpdate() {
        self.activityIndicator.startAnimating()
        self.companyNameLabel.text = "-"
        self.companyNameLabel.font = UIFont.systemFont(ofSize: self.companyNameLabel.font.pointSize)
        self.companySymbolLabel.text = "-"
        self.priceLabel.text = "-"
        self.priceChangeLabel.text = "-"
        self.priceChangeLabel.textColor = UIColor.black
        self.logoImageView.image = nil
        
        let selectedRow = self.companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = Array(self.companies.values)[selectedRow]
        self.requestQuote(for: selectedSymbol)
    }
    
    private func alertNetworkError() {
        
        let alert = UIAlertController(title: "Network Error", message: "Please, check your internet connection", preferredStyle: .alert)
        let retryAction = UIAlertAction(title: "Retry", style: .default) { _ in
            self.requestCompanyList()
        }
        alert.addAction(retryAction)
        present(alert, animated: true, completion: nil)
    }
    
    private func alertJSONError() {
        
        let alert = UIAlertController(title: "Error", message: "Oops! Something went wrong. please try again later", preferredStyle: .alert)
        let retryAction = UIAlertAction(title: "Ok", style: .default) { _ in
//            self.requestCompanyList()
        }
        alert.addAction(retryAction)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.companies.keys.count
    }
    
    // MARK: - UIPickerViewDelegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(self.companies.keys)[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.requestQuoteUpdate()
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.companyPickerView.dataSource = self
        self.companyPickerView.delegate = self
        
        self.activityIndicator.hidesWhenStopped = true
        
        self.requestCompanyList()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
