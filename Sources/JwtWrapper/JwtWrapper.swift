import Foundation

public typealias JwtBlock = () -> Void
public typealias JwtFunc<T> = (T) -> Void
public typealias JwtResponseHandler<T> = (Result<T, Error>) -> Void

public protocol JwtWrapperDelegate: AnyObject {
    func refreshTokens(completion: @escaping (_ success: Bool) -> Void)
    func shouldRefreshTokens(responseError: Error) -> Bool
}


public protocol JwtWrapper: AnyObject {
    
    var delegate: JwtWrapperDelegate! { get set }

    func reset() // should call on app logout

    func request<T>(
        requestMaker: (_ completion: @escaping (Result<T, Error>) -> Void) -> JwtBlock,
        responseHandler: @escaping JwtFunc<T?>
    )

}


public class JwtWrapperImpl: JwtWrapper {

    
    // MARK: JwtProvider
    
    public weak var delegate: JwtWrapperDelegate!

    public func request<T>(
        requestMaker: (@escaping JwtResponseHandler<T>) -> JwtBlock,
        responseHandler: @escaping JwtFunc<T?>
    ) {

        let regularRequest = requestMaker { [weak self] result in
            self?.applyResponseHandler(result, completion: responseHandler)
        }

        if tokenIsRefreshing {
            refreshTokenQueue.append(regularRequest)
            return
        }

        let jwtAwareRequest = requestMaker { [weak self] response in
            guard let self = self else { return }

            if self.shouldRefreshTokens(response: response) {
                
                self.refreshTokenQueue.append(regularRequest)
                
                if self.tokenIsRefreshing {
                    return
                }
                
                self.tokenIsRefreshing = true
                
                self.delegate.refreshTokens { success in
                    guard success else {
                        self.reset()
                        return
                    }
                    for request in self.refreshTokenQueue {
                        request()
                    }
                    self.reset()
                }
                
                return
            }

            self.applyResponseHandler(response, completion: responseHandler)
        }
        jwtAwareRequest()
    }

    public func reset() {
        refreshTokenQueue = []
        tokenIsRefreshing = false
    }

    
    // MARK: JwtProviderImpl
    
    private var tokenIsRefreshing = false
    private var refreshTokenQueue: Array<JwtBlock> = []
    
    public init() {}

    private func applyResponseHandler<T, E>(_ response: Result<T, E>, completion: JwtFunc<T?>) {
        switch response {
          case let .success(data):
            completion(data)
          default:
            completion(nil)
        }
    }

    private func shouldRefreshTokens<T, E>(response: Result<T, E>) -> Bool {
        switch response {
          case .success:
            return false
        case .failure(let error):
            return delegate.shouldRefreshTokens(responseError: error)
        }
    }


}
